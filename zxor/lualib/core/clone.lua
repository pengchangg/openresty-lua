--[[
深度复制
--]]
local table = require "core.table"

local _M = function(data)
	if type(data) == 'table' then
		return table.deepclone(data)
	else
		return data
	end
end

return _M