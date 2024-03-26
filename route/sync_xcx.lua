local collector = require("data.collector")
local event_statistics = require("data.event_statistics")
local c_user = require("data.user")

local ta_appid = {}
ta_appid["bb1bef8c4f3840388a95ff7ac997b87b"] = "appname"
ta_appid["2b6b291ee62b4cdf9d91f9c7e48fca07"] = "jjmj"

local _M = function(args, headers)
	local appname = ta_appid[args["#app_id"]] or false
	if not appname then
		return { code = 0 }
	end

	for _, event in ipairs(args.data) do
		local type = event["#type"] or ""
		if type == "user_setOnce" then
			-- 设置用户属性
			--   {
			--   "uid": "1234567890",
			--   "attribute": {
			--     "name":"张三",
			--     "age":20
			--   },
			--   "once": 0
			-- }
			local account_id = event["#account_id"] or false
			if not account_id then
				return { code = 0 }
			end
			local attribute = event
			local user = c_user:new(appname, account_id)
			user:set(attribute, false)
		elseif type == "track" then
			local event_id = event["#event_name"] or false

			if not event_id then
				return { code = 0 }
			end

			-- 事件
			event.event_id = event_id

			app.thread_report:add(collector.report, appname, event)
			local statistics = app.statics[appname]
			if statistics then
				statistics:trigger(event)
			end
			event_statistics.statistics_event_num(appname, event_id)
		end
	end

	return { code = 0 }
end

return _M
