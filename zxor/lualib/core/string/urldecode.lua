local s_gsub = string.gsub
local s_char = string.char

local _M = function(s,big)
	if not s or #s<=0 then  return "" end
    s = s_gsub(s, '%%(%x%x)', function(h) 
		return s_char(tonumber(h, 16))
	end) 
	return s
end

return _M