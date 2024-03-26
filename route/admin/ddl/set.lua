local respond = core.respond

local ddl = require("common.ddl")

local _M = function(args, headers)
	local appname = args.appname
	local msg = "ok"
	local status = 0

	if not appname then
		msg = "appname is empty"
		status = 502
		return respond(status, nil, msg, nil)
	end

	local ddl_string = args.ddl

	if not ddl_string then
		msg = "ddl is empty"
		status = 502
		return respond(status, nil, msg, nil)
	end

	local ret, error = ddl.exec(appname, ddl_string,args.remark)
	if not ret then
		status = 502
		msg = error or ""
	end

	return respond(status, nil, msg, nil)
end

return _M
