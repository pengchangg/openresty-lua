local openfile = io.open
local closefile = io.close

local _M = function(filepath)
	local file = openfile(filepath,'r')
	if not file then return false end 
	
	local data = file:read("*a")
	
	file:close()
	
	return data
end

return _M