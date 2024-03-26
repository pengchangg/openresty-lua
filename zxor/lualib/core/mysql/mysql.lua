--[[
mysql对象
--]]
local class = require "core.class"
local mysql = require "resty.mysql"

local get_address = require 'core.dns.getaddress'

local _M = class()

function _M:__init(host,port,user,password,database,charset)
	self.host = get_address(host)
	self.port = port
	self.user = user
	self.password = password
	self.database = database
	self.charset = charset
	self.conn_args = {
		host = self.host,
		port = self.port,
		user = self.user,
		password = self.password,
		database = self.database,
		charset = charset or self.charset or 'utf8'
	}
	self:open()
end

function _M:open(charset)
	if self.con then return true,"success" end
	local con = mysql:new()
	if not con then return false,"create mysql connect failed." end
	con:set_timeout(30000)
	local result,errmsg,errno,state = con:connect(self.conn_args)
	if not result then
		return false,errmsg
	end
	self.con = con
	self:query("SET NAMES '" .. (charset or self.charset or 'utf8') .. "'")
	return true,"success"
end

function _M:query(sql)
	if not self.con then
		local ok,err = self:open()
		if not ok then return false, err or "no connect" end
	end
	if not self.con then return false,'no connect 1' end
	local result, errmsg, errno, sqlstate = self.con:query(sql)
	if not result then
		self:close(true)
		errmsg = errmsg or 'no result'
	elseif errmsg == 'again' then
		local tmp = result
		result = {tmp}
		while errmsg == 'again' do
			tmp,errmsg = self.con:read_result()
			result[#result+1] = tmp
		end
	end
    return result, errmsg
end

function _M:close(realy)
	if self.con then
		if realy then 
			self.con:close()
		else
			self.con:set_keepalive(60000, 100)
		end
	end
	self.con = nil
end

return _M