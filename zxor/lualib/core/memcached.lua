--[[
memcached对象
--]]
local ngx = ngx
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local semaphore = require "ngx.semaphore"
local sleep = ngx.sleep

local memcached_c = require "resty.memcached"

local pool_max_idle_time = 50000 --毫秒  
local pool_size = 500 --连接池大小  
local sock_timeout = 5000
local get_address = require 'core.dns.getaddress'
local s_len = string.len


local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function(narr, nrec) return {} end
end

local _M = new_tab(0, 155)
_M._VERSION = '0.01'

local commands = {
    'get','gets',
	'set','add','resplace','append','prepend',
	'cas',
	'delete',
	'flush_all',
	'incr','decr',
	'stats','version','quit',
	'verbosity','touch',
}

local mt = { __index = _M }

local function new_con(self)
	if self.inuse >= self.concurrency then
		while self.inuse >= self.concurrency do
			self.sema:wait(1)
		end
	end
	
	self.inuse = self.inuse + 1
	local mem, err = memcached_c:new({key_transform = self.key_transform})
	
	return mem,err
end

local function release_con(self)
	
	self.inuse = self.inuse - 1
	self.sema:post(1)

end

function _M.set_keepalive_mod(mem)
    -- put it into the connection pool of size 100, with 60 seconds max idle time
    return mem:set_keepalive(pool_max_idle_time, pool_size)
end

-- change connect address as you need
function _M.connect_mod(self, mem)
    mem:set_timeout(self.timeout)
    self.host = get_address(self.host)
    local ok, err = mem:connect(self.host, self.port)
    if self.password and s_len(self.password) > 0 then
        local count, err = mem:get_reused_times()
        if count == 0 then 
			--ok, err = mem:auth(self.user,self.password)
			--core.log.info(err)
		end
    end
    return ok, err
end

local function is_mem_null(res)
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

local function do_command(self, cmd, ...)
    if self._reqs then
        table.insert(self._reqs, { cmd, ... })
        return
    end

    local mem, err = new_con(self)
    if not mem then
		release_con(self)
        return nil, err
    end

    local ok, err = self:connect_mod(mem)
    if not ok or err then
		release_con(self)
        return nil, err
    end

    local fun = mem[cmd]
    local result, err,err2 = fun(mem, ...)
    if not result then
        -- ngx.log(ngx.ERR, "pipeline result:", result, " err:", err)
		release_con(self)
        return nil, (err or '') .. (err2 or '')
    end

    if is_mem_null(result) then
        result = nil
    end

    self.set_keepalive_mod(mem)
	release_con(self)
    return result, err
end

function _M.new(self, opts)
    opts = opts or {}

    local timeout = (opts.timeout and opts.timeout * 1000) or sock_timeout
    local host = opts.host or "127.0.0.1"
    local port = opts.port or 11211
    local user = opts.user or opts.username or ""
    local password = opts.password or ""
	local concurrency = opts.concurrency or 1000

    for i = 1, #commands do
        local cmd = commands[i]
        _M[cmd] =        function(self, ...)
            return do_command(self, cmd, ...)
        end
    end

    return setmetatable({
        timeout = timeout,
        host = host,
        port = port,
        user = user,
        password = password,
		key_transform = opts.key_transform,
        _reqs = nil,
		inuse = 0,
		concurrency = concurrency,
		sema = semaphore:new(),
    }, mt)
end

return _M