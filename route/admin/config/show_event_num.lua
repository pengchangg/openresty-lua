local respond = core.respond
local event_statistics = require("data.event_statistics")

local _M = function(args, _)
	local appname = args.appname
	if not appname then
		return respond(502, nil, "appname is empty", nil)
	end

	local event_id = args.event_id or ""
	local data = {}

	if event_id == "" then
		data, _ = event_statistics.get_statistics_event_num_all(appname)
	else
		local t, _ = event_statistics.get_statistics_event_num(appname, event_id)
		table.insert(data, t)
	end

	return respond(0, data, "ok", nil)
end

return _M
