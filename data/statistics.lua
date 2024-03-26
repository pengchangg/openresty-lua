local prefix = "statistics:user:script:"
local _M = {}
local logerr = core.log.error
local loginfo = core.log.info
local encode = core.cjson.encode
local decode = core.cjson.decode
local now = ngx.now
local dingTalk = require("zxor.lualib.third.dingtalk.robot")
local now_date = os.date

---@diagnostic disable-next-line: undefined-field
local stream = db.redis

local cmds = {
	--keys
	"del",
	"exists",
	"expire",
	"expireat",
	"pexpire",
	"pexpireat",
	"keys",
	"move",
	"persist",
	"pttl",
	"ttl",
	"type",
	"sort",

	--string
	"set",
	"get",
	"getrange",
	"getset",
	"getbit",
	"mget",
	"setbit",
	"setnx",
	"setrange",
	"strlen",
	"mset",
	"msetnx",
	"psetex",
	"incr",
	"incrby",
	"incrbyfloat",
	"append",
	"setex",
	"decr",
	"decrby",

	--hash
	"hdel",
	"hexists",
	"hget",
	"hgetall",
	"hincrby",
	"hincrbyfloat",
	"hkeys",
	"hlen",
	"hmget",
	"hmset",
	"hset",
	"hsetnx",
	"hvals",
	"hscan",
	"hstrlen",

	--list
	"blpop",
	"brpop",
	"brpoplpush",
	"lindex",
	"linsert",
	"llen",
	"lpop",
	"lpush",
	"lpushx",
	"lrange",
	"lrem",
	"lset",
	"ltrim",
	"rpop",
	"rpoplpush",
	"rpush",
	"rpushx",

	--set
	"sadd",
	"scard",
	"sdiff",
	"sdiffstore",
	"sinter",
	"sinterstore",
	"sismember",
	"smembers",
	"smove",
	"spop",
	"srandmember",
	"srem",
	"sunion",
	"sunionstore",
	"sscan",

	--sorted set
	"zadd",
	"zcard",
	"zcount",
	"zincrby",
	"zinterstore",
	"zlexcount",
	"zrange",
	"zrangebylex",
	"zrangebyscore",
	"zrank",
	"zrem",
	"zremrangebylex",
	"zremrangebyrank",
	"zremrangebyscore",
	"zrevrange",
	"zrevrangebyscore",
	"zrevrank",
	"zscore",
	"zunionstore",
	"zscan",
}

function _M.new(appname)
	if app.statics[appname] then
		return app.statics[appname]
	end

	local static = {
		appname = appname,
		prefix = prefix .. appname .. ":",
		prefix_user = prefix .. appname .. ":user:",
		---@diagnostic disable-next-line: undefined-field
		redis = db.redis,
		---@diagnostic disable-next-line: undefined-field
		mysql = db.mysql,
		---@diagnostic disable-next-line: undefined-field
		cache = cache.user,
		scripts = {},
		encode = encode,
		decode = decode,
		now_date = now_date,
		dingTalk = dingTalk,
		script_id = "",
	}

	app.statics[appname] = setmetatable(static, { __index = _M })
	return app.statics[appname]
end

for _, cmd in ipairs(cmds) do
	_M[cmd] = function(self, key, ...)
		return self.redis[cmd](self.redis, self.prefix .. key, ...)
	end
end

function _M.append(self, tablename, records)
	local tn = "t_" .. tablename .. "_" .. self.appname
	local fields = {}
	local values = {}

	for _, record in ipairs(records) do
		local fields_tmp = {}
		local values_tmp = {}
		for key, value in pairs(record) do
			table.insert(fields_tmp, key)
			table.insert(values_tmp, "'" .. value .. "'")
		end
		table.insert(values, string.format("(%s)", table.concat(values_tmp, ", ")))
		fields = fields_tmp
	end

	local sql =
		string.format("INSERT INTO %s (%s) VALUES %s ", tn, table.concat(fields, ", "), table.concat(values, ","))

	return self.mysql:query(sql)
end

function _M.get_user(self, uid)
	return {
		get = function(_, key)
			local user = self.cache:get(self.prefix_user .. uid)
			return user[key] or nil
		end,
		set = function(_, data)
			self.cache:set(self.prefix_user .. uid, data)
		end,
	}
end

function _M.dump(self, ...)
	local args = { ... }
	local logdata = {
		date = now_date("%Y-%m-%d %H:%M:%S"),
		output = encode(args),
	}

	local k = "statistics:log-watch:" .. self.appname
	stream:publish(k, encode(logdata))

	if self.script_id ~= "" then
		local k_script_id = "statistics:log-watch:" .. self.appname .. ":" .. self.script_id
		stream:publish(k_script_id, encode(logdata))
	end
end

local process = function(self, eventdata)
	for id, script in pairs(self.scripts[eventdata.event_id] or {}) do
		local t1 = now()
		self.script_id = tostring(id)
		local ok, ret1, ret2 = pcall(script.func, self, eventdata, id)
		if not ok then
			logerr("scripts processing script_failed appname =  ", self.appname, ",script_id = ", id)
		else
			if ret1 then
				loginfo("scripts processing  success appname = ", self.appname, ",script_id = ", id)
			else
				logerr(
					"scripts processing  return_error appname = ",
					self.appname,
					",script_id = ",
					id,
					",err = ",
					ret2
				)
			end
		end

		local logdata = {
			date = now_date("%Y-%m-%d %H:%M:%S"),
			script_id = id,
			ok = ok,
			ret1 = ret1 or "",
			ret2 = ret2 or "",
			execution_time = now() - t1,
		}

		local k = "statistics:log-watch:" .. self.appname
		stream:publish(k, encode(logdata))

		local k_script_id = "statistics:log-watch:" .. self.appname .. ":" .. id
		stream:publish(k_script_id, encode(logdata))
	end
end

function _M.append_script(self, id, script)
	id = tostring(id)
	local event_id = script.event_id
	if not event_id then
		return false, "no eveit_id"
	end

	self.scripts[event_id] = self.scripts[event_id] or {}
	local tmp = {}
	tmp.id = id
	tmp.func = script.func

	self.scripts[event_id][id] = tmp
end

function _M.remove_script(self, event_id, id)
	id = tostring(id)
	if self.scripts[event_id] then
		self.scripts[event_id][id] = nil
	end
end

function _M.trigger(self, event)
	app.thread_statistics:add(process, self, event)
end

return _M
