local s_gsub = string.gsub
local s_fmt = string.format
local s_byte = string.byte

local _M = function(s,big)
	if not s or #s<=0 then  return "" end
    s = s_gsub(s, "([^%w%.%- ])", function(c)
		if big then
			return s_fmt("%%%02X", s_byte(c))
		else
			return s_fmt("%%%02x", s_byte(c))
		end
	end)  
    return s_gsub(s, " ", "+")  
end

return _M