--[[
redis对象
--]]
local ngx = ngx
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local semaphore = require "ngx.semaphore"
local sleep = ngx.sleep
local now = ngx.now

local redis_c = require "resty.redis"

local pool_max_idle_time = 60000 --毫秒
local pool_size = 2000 --连接池大小
local sock_timeout = 5000
local get_address = require 'core.dns.getaddress'
local s_len = string.len

local table = require "core.table"
local go = require "core.go"

local new_tab = table.new
local del_tab = table.release
local set_gc = table.gc

local t_insert = table.insert
local t_remove = table.remove

local _M = new_tab(0, 155)
_M._VERSION = '0.01'

local commands = {
    --keys
    "del","exists","expire","expireat","pexpire","pexpireat","keys","move","persist",
    "pttl","ttl","randomkey","rename","renamenx","scan","type","sort",

    --string
    "set","get","getrange","getset","getbit","mget","setbit","setnx","setrange","strlen",
    "mset","msetnx","psetex","incr","incrby","incrbyfloat","append","setex","decr","decrby",

    --hash
    "hdel","hexists","hget","hgetall","hincrby","hincrbyfloat","hkeys","hlen","hmget","hmset",
    "hset","hsetnx","hvals","hscan","hstrlen",

    --list
    "blpop","brpop","brpoplpush","lindex","linsert","llen","lpop","lpush","lpushx","lrange",
    "lrem","lset","ltrim","rpop","rpoplpush","rpush","rpushx",

    --set
    "sadd","scard","sdiff","sdiffstore","sinter","sinterstore","sismember","smembers","smove",
    "spop","srandmember","srem","sunion","sunionstore","sscan",

    --sorted set
    "zadd","zcard","zcount","zincrby","zinterstore","zlexcount","zrange","zrangebylex",
    "zrangebyscore","zrank","zrem","zremrangebylex","zremrangebyrank","zremrangebyscore",
    "zrevrange","zrevrangebyscore","zrevrank","zscore","zunionstore","zscan",

    --hyperLoglog
    "pfadd","pfcount","pfmerge",

    --geo
    "geoadd","geopos","geodist","georadius","georadiusbymember","geohash",

    --bitmap
    "setbit","getbit","bitcount","bitpos","bitop","bitfield",

    --pubsub
    --[[ "psubscribe","punsubscribe","subscribe","unsubscribe", ]]
    "pubsub","publish",

    --transaction
    "discard","exec","multi","unwatch","watch",

    --script
    "eval","evalsha","script",

    --stream
    "xadd","xtrim","xdel","xlen","xrange","xrevrange","xread","xgroup","xreadgroup","xack",
    "xpending","xclaim","xinfo",

    --connection
    "auth","quit","select",

    --server
    "bgrewriteaof","bgsave","client","cluster","command","time","config","dbsize","swapdb",
    "flushall","flushdb","info","lastsave","role","save","shutdown","slaveof","object",

    --debug
    "ping","echo","object","slowlog","monitor","debug",

    --internal
   "migrate","restore","dump","sync","psync",
}

local mt = { __index = _M }

local function is_redis_null(res)
    if type(res) == "table" then
        for k, v in pairs(res) do
            if v ~= ngx.null then
                return false
            end
        end
        return true
    elseif res == ngx.null then
        return true
    elseif res == nil then
        return true
    end

    return false
end

local new_con = function(self)
	while self._redis.inuse >= self._redis.max do
		self.sema:wait(30)
	end

	local redis, err = redis_c:new()
	if not redis then return nil, err end

	redis:set_timeout(self.timeout)
    self.host = get_address(self.host)
    local ok, err = redis:connect(self.host, self.port)
	if not ok then return nil,err end

    local count = redis:get_reused_times()
    if count == 0 then
        if self.password and s_len(self.password) > 0 then
			ok, err = redis:auth(self.password)
		end
        if ok and self.db_index and self.db_index > 0 then
            redis:select(self.db_index)
        end
    end

	if not ok then
		redis:close()
		return nil,err
	end

	self._redis.inuse = self._redis.inuse + 1
    return redis
end

local function release_con(self, redis, closed)
	if redis then
		if closed then
			redis:close()
		else
			redis:set_keepalive(self.max_idle_time or pool_max_idle_time, self.pool_size or pool_size)
		end
	end

	self._redis.inuse = self._redis.inuse - 1
	self.sema:post(1)
end

_M.new_con = new_con
_M.release_con = release_con

function _M.init_connect_pool(self,num)
	num = num or self._redis.max
	if num > self._redis.max then num = self._redis.max end

	local pools = {}
	for i = 1,num do
		pools[i] = new_con(self)
	end

	for i = 1,num do
		release_con(self, pools[i])
	end
end

function _M.init_pipeline(self)
	local redis,err = new_con(self)
	if not redis then return redis,err end
	redis:init_pipeline()
	return redis
end

function _M.cancel_pipeline(self,redis)
	if not redis then return false,'redis is nil' end
	redis:cancel_pipeline()
	release_con(self,redis)
	return true
end

function _M.commit_pipeline(self, redis)
	if not redis then return false,'redis is nil' end
	local results, err = redis:commit_pipeline()
    if not results or err then
		release_con(self, redis, true)
        return {}, err
    end

    if is_redis_null(results) then
        results = {}
        ngx.log(ngx.WARN, "is null")
    end

 	release_con(self, redis)

    for i, value in ipairs(results) do
        if is_redis_null(value) then
            results[i] = nil
        end
    end

    return results, err
end

local _subscribed = function (self, channel)
    local redis, err = new_con(self)
    if not redis then
        return nil, err
    end

    local res, err = redis:subscribe(channel)
    if not res then
		release_con(self, redis, true)
        return nil, err
    end

    local function do_read_func(do_read)
        if do_read == nil or do_read == true then
            res, err = redis:read_reply()
            if not res then
				if err ~= 'timeout' then
					release_con(self, redis, true)
				end
                return nil, err
            end
            return res
        end

        redis:unsubscribe(channel)
		release_con(self, redis)

		return nil
    end

    return do_read_func
end

function _M.subscribe(self, channel, on_message, on_error, on_close)
    if not channel then
        return false, 'no channel'
    end

    if type(on_message) ~= 'function' then
        return _subscribed(self, channel)
    end

    local exit_loop = false
    while not worker.killed do
        local _poll = _subscribed(self, channel)
        if _poll then
            local msg, err = _poll(not worker.killed)
            while msg or err == 'timeout' do
                if msg and #msg == 3 and msg[1] == 'message' and msg[2] == channel then
                    if on_message(msg[3]) == 'exit' then
                        exit_loop = true
                        break
                    end
                end
                msg, err = _poll(not worker.killed)
            end

            if err and err ~= 'timeout' then
                core.log.error('error: subscribe ' .. channel .. ' failed err -> ',err)
                if type(on_error) == 'function' then
                    if on_error(err) == 'exit' then
                        exit_loop = true
                    end
                end
            end
        end

        if exit_loop then
            break
        end
    end

    if type(on_close) == 'function' then
        on_close()
    end
end

local _psubscribe = function(self, channel)
    local redis, err = new_con(self)
    if not redis then
        return nil, err
    end

    local res, err = redis:psubscribe(channel)
    if not res then
		release_con(self, redis, true)
        return nil, err
    end

    local function do_read_func(do_read)
        if do_read == nil or do_read == true then
            res, err = redis:read_reply()
            if not res then
				if err ~= 'timeout' then
					release_con(self, redis, true)
				end
                return nil, err
            end
            return res
        end

        redis:punsubscribe(channel)
		release_con(self, redis)

		return nil
    end

    return do_read_func
end

function _M.psubscribe(self, channel, on_message, on_error, on_close)
    if not channel then
        return false, 'no channel'
    end

    if type(on_message) ~= 'function' then
        return _psubscribe(self, channel)
    end

    while not worker.killed do
        local _poll = _psubscribe(self, channel)
        if _poll then
            local msg, err = _poll(not worker.killed)
            while msg or err == 'timeout' do
                if msg and #msg == 3 and msg[1] == 'message' then
                    on_message(msg[2], msg[3])
                end
                msg, err = _poll(not worker.killed)
            end

            if err and err ~= 'timeout' then
                core.log.error('error: subscribe ' .. channel .. ' failed err -> ',err)
                if type(on_error) == 'function' then
                    on_error(err)
                end
            end
        end
    end

    if type(on_close) == 'function' then
        on_close()
    end
end

local function do_command(self, cmd, ...)
    local redis, err = new_con(self)
    if not redis then
        return nil, err
    end

    local fun = redis[cmd]
    local result, err = fun(redis, ...)
    if not result or err then
		release_con(self, redis, true)
        return nil, err
    end

    if is_redis_null(result) then
        result = nil
    end

	release_con(self, redis)
    return result, err
end

function _M.new(self, opts)
    opts = opts or {}

    local timeout = (opts.timeout and opts.timeout * 1000) or sock_timeout
    local db_index = opts.db_index or 0
    local host = opts.host or "127.0.0.1"
    local port = opts.port or 6379
    local password = opts.password or ""
	local concurrency = opts.concurrency or 1000

    for i = 1, #commands do
        local cmd = commands[i]
        _M[cmd] = function(self, ...)
            return do_command(self, cmd, ...)
        end
    end

	local redis_list = new_tab(0,3)
	redis_list.max = concurrency
	redis_list.inuse = 0

    return setmetatable({
        timeout = timeout,
        db_index = db_index,
        host = host,
        port = port,
        password = password,
		max_idle_time = opts.max_idle_time,
		pool_size = opts.pool_size,
		_redis = redis_list,
		sema = semaphore:new(),
    }, mt)
end

local locker_metatable = {
    __index = {
        lock = function (self, timeout)
            if self.block and now() - self.block < self.timeout then
                return true
            end

            local islock = false
            local step = 0.01
            local maxstep = timeout / 10
            timeout = timeout or 60
            local btime = now()
            while not islock and now() - btime < timeout do
                islock = self.pool:set(self.name, 1, "ex", self.timeout, "nx")
                if not islock then
                    ngx.sleep(step)
                    step = math.min(step * 2, maxstep)
                end
            end

            if not islock then
                return false, "failed to lock"
            end

            self.block = now()
            return true
        end,
        unlock = function (self)
            if self.block and now() - self.block + 0.01 < self.timeout then
                if self.pool:del(self.name) then
                    self.block = false
                end
            end
        end,
    }
}

local locker_gc = function (locker)
    go(0, locker.unlock, locker)
end

function _M.new_locker(self, name, timeout)
    local locker = new_tab(0,4)
    locker.name = name
    locker.timeout = timeout or 60
    locker.pool = self
    locker.block = false
    setmetatable(locker, locker_metatable)
    set_gc(locker, locker_gc)

    return locker
end

return _M