--[[
日志
--]]
local ngx_log  = ngx.log
local ngx_updatetime = ngx.update_time
local ngx_now = ngx.now
local cjson = require 'core.cjson'
local cjson_encode = cjson.encode

local _M = {version = 0.1}
local cmds = {
	stderr = ngx.STDERR,
	emerg  = ngx.EMERG,
	alert  = ngx.ALERT,
	crit   = ngx.CRIT,
	error  = ngx.ERR,
	warn   = ngx.WARN,
	notice = ngx.NOTICE,
	info   = ngx.INFO,
}

for name, log_level in pairs(cmds) do
    _M[name] = function(...)
        return ngx_log(log_level, ...)
    end
end

_M.timer = function(prefix)
	ngx_updatetime()
	local btime = ngx_now()
	return function(new_prefix, bretime, mincost, recflag)
		ngx_updatetime()
		local etime = ngx_now()
		local cost = etime * 1000 - btime * 1000
		if bretime then
			btime = etime
		end
		if not mincost or cost >= mincost then
			if recflag then
				return ngx_log(ngx.INFO, '[', recflag, '] ', cjson_encode({
					cost = cost,
					prefix = prefix or new_prefix
				}))
			else
				return ngx_log(ngx.INFO, prefix or new_prefix or '',' cost time = ', cost, 'ms')
			end
		end
	end
end

_M.record = function(flag,rec)
	return ngx_log(ngx.INFO, '[', flag, '] ', cjson_encode(rec))
end

return _M
