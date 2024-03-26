local xml2lua = require 'resty.xml.xml2lua'
local handler = require 'resty.xml.xmlhandler.tree'

local _parse = function(xmlstring)
	local h = handler:new()
	local p,err = xml2lua.parser(h)
	if not p then return false,err end
	
	local ok,err = p:parse(xmlstring)
	if not ok then return false,err end
	
	return h.root
end

local _M = {
	parse = _parse,
	make = xml2lua.toXml,
}

return _M