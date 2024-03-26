---@diagnostic disable-next-line: undefined-field
local mysql = db.mysql
---@diagnostic disable-next-line: undefined-field
local stream = db.redis

local logerr = core.log.error
local cjson_decode = core.cjson.decode
local cjson_encode = core.cjson.encode

local utils = require("common.utils")
local db = require("common.db")

local cron = require("data.cron")
local statistics = require("data.statistics")

local tablename = "sys_script"

local _M = {}

local watch_script_change_channel = "statistics:script:subscribe:changed"
local watch_script_change = function()
	core.go(0, function()
		stream:subscribe(watch_script_change_channel, function(message)
			local data = cjson_decode(message)

			if data and data.appname and data.id and data.script then
				local func = utils.convert_string_to_script(data.script.func)

				if type(func) ~= "function" then
					return
				end

				data.script.func = func
				if data.script.type == "event" then
					-- remove_script
					local stat = statistics.new(data.appname)
					stat:remove_script(data.script.event_id, data.id)
					if data.verify < 1 then
						return
					end
					stat:append_script(data.id, data.script)
				elseif data.script.type == "timer" then
					if data.verify < 1 then
						cron.remove(data.appname, data.id)
					else
						cron.append(data.appname, data.id, data.script)
					end
				end
			end
		end)
	end)
end

local function load_all()
	local rs, err = mysql:query("select `id`, `appname`, `script` from `sys_script` where `verify` > 0")
	if not rs then
		logerr("load timer config from db failed -> ", err)
		return
	end

	for _, conf in ipairs(rs) do
		local script, err2 = cjson_decode(conf.script)
		if script then
			local func = utils.convert_string_to_script(script.func)
			if type(func) == "function" then
				script.func = func
				if script.type == "timer" then
					cron.append(conf.appname, conf.id, script)
				else
					local stat = statistics.new(conf.appname)
					stat:append_script(conf.id, script)
				end
			end
		else
			logerr("init ", conf.appname, " timer failed -> ", err2)
		end
	end

	watch_script_change()

	cron:run()
end

_M.load = function()
	core.go(0, load_all)
end

_M.get = function(appname)
	local select_sql = string.format("select * from `%s` where `appname` = '%s' and verify > 0   ", tablename, appname)
	return mysql:query(select_sql)
end

_M.sync_script = function(appname, script_list)
	for _, script in ipairs(script_list) do
		local t = {}
		t.appname = appname
		t.verify = 1
		t.script = cjson_encode(script)

		local id, _ = db.insert_db_return_last_id(tablename, t)

		stream:publish(
			watch_script_change_channel,
			cjson_encode({
				appname = appname,
				id = id,
				script = script,
				verify = 1,
			})
		)
	end
	return true, nil
end

_M.set = function(appname, plan_id, id, script, verify, remark)
	id = tonumber(id) or 0
	local t = {}
	t.appname = appname
	-- t.plan_id = plan_id or 0
	t.verify = tonumber(verify)
	t.script = cjson_encode(script)
	t.remark = remark or ""
	local err = nil

	if id > 0 then
		local condition = " id = " .. id
		-- update
		_, err = db.updae_db(tablename, t, condition)
	else
		-- add
		id, err = db.insert_db_return_last_id(tablename, t)
	end

	stream:publish(
		watch_script_change_channel,
		cjson_encode({
			appname = appname,
			id = id,
			script = script,
			verify = verify,
		})
	)

	if err then
		return false, err
	end

	return true, nil
end

return _M
