--[[
重载脚本
--]]
local require = require

local _M = function(script, check_type)
	if config.debug then
		package.loaded[script] = nil
	end

	return require(script)
end

return _M