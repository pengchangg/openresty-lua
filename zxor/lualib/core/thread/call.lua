local core_table = require 'core.table'
local newtable = core_table.new
local semaphore = require "ngx.semaphore"

local _M = {version = 0.1}
local mt = {__index = _M}

local serial_id = 10000

_M.new = function(self,callback)
	serial_id = serial_id + 1
	if serial_id > 99999999 then serial_id = 10000 end

	local m = newtable(0,5)
	m.id = serial_id
	if type(callback) == "function" then
		m.cb = callback
		m.type = 'async'
	else
		m.type = 'sync'
		m.sema = semaphore:new()
	end
	
	return setmetatable(m,mt)
end

_M.is_sync = function (self)
	return self.type == 'sync'
end

_M.wait = function (self,timeout)
	if not self.sema then
		return false,'the callback does not need to wait.'
	end

	self.ret = nil
	timeout = timeout or 86400
	self.sema:wait(timeout)

	if not self.ret then return false,'time out' end

	return unpack(self.ret)
end

_M.exec = function (self,...)
	if self.sema then
		self.ret = {...}
		self.sema:post(1)
		return true
	elseif self.cb then
		return self.cb(...)
	end
end

return _M

