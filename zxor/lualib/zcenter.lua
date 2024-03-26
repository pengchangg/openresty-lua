--[[
公共方法加载
--]]
local _M = {
	mesh = require 'zcenter.mesh',
	stream = require 'zcenter.stream',
	config = require 'zcenter.config',
}

local conf = config.zcenter

if not conf then
	return false
end

--修正respond结构
local new_table = require('core.table').new
local respond = function(status,data,msg,extra)
	local rs = new_table(0,5,'core.respond.data')
	rs.result = status
	rs.data = data
	rs.errmsg = msg
	rs.extra = extra
	rs.__make_by_respond = true
	return rs
end
core.respond = respond

if type(conf) ~= 'table' then
	conf = {}
end

if not conf.port and config.http_ports then
	conf.port = config.http_ports[1]
end

config.zcenter = conf

_M.init = function()
	_M.mesh.init()
	_M.stream.init()
	_M.config.init()

	if config.init then
		local env,err = nil,nil
		for _ = 1, 3 do
			env,err = _M.config.get_env()
			if env then
				break
			end
		end
		
		if not env then
			core.log.record('error',{msg = 'get devops env failed.', err = err})
		end

		_M.env = env
	end
end

return _M