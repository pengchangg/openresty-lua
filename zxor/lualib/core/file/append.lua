local openfile = io.open
local closefile = io.close
local type = type

local _M = function(filepath,data)
	local dt = type(data)
	if dt ~= 'string' and dt ~= 'number' then return false,'wrong data type' end
	
	local file = openfile(filepath,'a')
	if not file then return false,'open file failed' end 
	
	file:write(data)
	file:close()
	
	return true
end

return _M