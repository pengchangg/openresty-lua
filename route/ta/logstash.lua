local respond = core.respond
local loginfo = core.log.info
local encode = core.cjson.encode
local decode = core.cjson.decode
local collector = require("data.collector")
local c_user = require("data.user")
local event_statistics = require("data.event_statistics")

local ta_appid = {}
ta_appid["bb1bef8c4f3840388a95ff7ac997b87b"] = "appname"
ta_appid["2b6b291ee62b4cdf9d91f9c7e48fca07"] = "jjmj"

local _M = function(args, headers)
	local appname = ta_appid[headers["ta-appid"]] or false
	if not appname then
		return respond(0, nil, "ta-appid is null", nil)
	end

	local event = decode(args.message)

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
			return respond(0, nil, "#account_id is null", nil)
		end
		local attribute = event
		local user = c_user:new(appname, account_id)
		user:set(attribute, false)
	elseif type == "track" then
		local event_id = event["#event_name"] or false

		if not event_id then
			return respond(0, nil, "#event_name is null", nil)
		end

		-- 事件
		event.event_id = event_id

		app.thread_report:add(collector.report, appname, event)
		local statistics = app.statics[appname]
		if statistics then
			statistics:trigger(event)
		end
		event_statistics.statistics_event_num(appname, event_id)
	else
		return respond(0, nil, "#type is " .. type, nil)
	end

	return respond(0, nil, "OK", nil)
end

return _M
