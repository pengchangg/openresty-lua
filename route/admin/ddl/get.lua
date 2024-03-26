local respond = core.respond
local db = require("common.db")
local _M = function(args, headers)
	local condition = nil
	if args.appname and #args.appname > 0 then
		condition = " appname = " .. ngx.quote_sql_str(args.appname)
	end
	local data, err = db.get("sys_table_ddl", condition)
	return respond(0, data, err, nil)
end

return _M
