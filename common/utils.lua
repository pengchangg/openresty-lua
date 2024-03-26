local _M = {}

_M.convert_string_to_script = function(str)
	local f = loadstring(str)
	if type(f) == "function" then
		return f()
	end
	return nil, "wrong script"
end

return _M
