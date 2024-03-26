local respond = core.respond
local scripts = require("data.scripts")
local db = require("common.db")

local _M = function(args, headers)
	local condition = nil
	if args.appname and #args.appname > 0 then
		condition = " appname = " .. ngx.quote_sql_str(args.appname)
	end
	local data, error = db.get("sys_script", condition)
	return respond(0, data, error, nil)
end

return _M
