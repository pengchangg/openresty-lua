--[[
DNS接口集合
--]]
local getaddress = require 'core.dns.getaddress'
local gethostfromurl = require 'core.dns.gethostfromurl'

local _M = {}


_M.get_address = getaddress
_M.get_host_from_url = gethostfromurl


return _M