local respond = core.respond
local collector = require("data.collector")
local event_statistics = require("data.event_statistics")

local _M = function(args, headers)
	app.thread_report:add(collector.report, headers.appname, args)
	local statistics = app.statics[headers.appname]
	if statistics then
		statistics:trigger(args)
	end
	event_statistics.statistics_event_num(headers.appname, args.event_id)
	return respond(0, nil, "OK", nil)
end

return _M
