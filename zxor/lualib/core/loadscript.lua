--[[
重载脚本
--]]
local require = require
local type = type
local pcall = pcall

local _M = function(script, check_type)
	if config.debug then
		package.loaded[script] = nil
	end

	local ok, rs = pcall(require, script)
	if not ok then
		core.log.error("load script failed -> ", rs)
		return nil, rs
	end

	if check_type and type(rs) ~= check_type then
		core.log.error("load script failed -> wrong return type -> ", script, ' ==> ', type(rs))
		return nil, 'wrong type'
	end

	return rs
end

return _M