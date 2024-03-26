local respond = core.respond

local c_user = require("data.user")

--[[
	{
	"uid": "1234567890",
	"attribute": {
		"name":"张三",
		"age":20
	},
	"once": 0
}
]]
local _M = function(args, headers)
	local user = c_user:new(headers.appname, args.uid)
	local ok, msg = user:set(args.attribute, args.update == 1)

	if not ok then
		return respond(502, nil, msg, nil)
	end
	return respond(0, msg, "OK", nil)
end

return _M
