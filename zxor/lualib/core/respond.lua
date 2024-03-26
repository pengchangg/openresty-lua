--[[
http模式下的统一回复
--]]
local new_table = require("core.table").new

local _M = function(status, data, msg, extra)
	local rs = new_table(0, 5, "core.respond.data")
	rs.status = status
	rs.msg = msg
	rs.data = data or ""
	rs.extra = extra
	rs.__make_by_respond = true
	return rs
end

return _M

