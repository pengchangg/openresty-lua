local respond = core.respond
local application = require("data.application")
local _M = function(args, headers)
	if not args.appname then
		return respond(502, nil, "appname is empty", nil)
	end
	local msg, status = application.add(args, headers)

	return respond(status, nil, msg, nil)
end

return _M
