local _M = {}

_M.writer = function(data, filename)
	local f, err = io.open(filename, "a")
	if err or f == nil then
		return false, err
	end

	f:write(table.concat(data, "\n"))
	f:write("\n")

	f:close()
	return true
end

return _M
