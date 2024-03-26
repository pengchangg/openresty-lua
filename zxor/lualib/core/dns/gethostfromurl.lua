local sfind = string.find
local ssub = string.sub
local slen = string.len

local get_address = require 'core.dns.getaddress'

local _M = function(url)
	local _,p1 = sfind(url,'://')
	if not p1 then
		return nil,url
	end
	
	local p2,_ = sfind(url,'/',p1 + 1)
	if not p2 then p2 = slen(url) end
		
	local host = get_address(ssub(url,p1 + 1,p2 - 1))
	local newurl = ssub(url,1,p1) .. host .. ssub(url,p2)
	
	return host,newurl
end

return _M