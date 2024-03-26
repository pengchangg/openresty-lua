local respond = core.respond
local scripts = require("data.scripts")

local _M = function(args, headers)
	local ok, msg = scripts.set(args.appname, args.plan_id, args.id, args.script, args.verify, args.remark or "")
	if not ok then
		return respond(502, nil, msg, nil)
	end
	return respond(0, nil, "OK", nil)
end

return _M
