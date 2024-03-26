local str_split = core.string.split
local logerr = core.log.error
local loginfo = core.log.info
local encode = core.cjson.encode
local now = ngx.now
local now_date = os.date

---@diagnostic disable-next-line: undefined-field
local redis = db.redis
---@diagnostic disable-next-line: undefined-field
local mysql = db.mysql
---@diagnostic disable-next-line: undefined-field
local stream = db.redis

local prefix = "statistics:user:script"
local statistics = require("data.statistics")

local current_week = 0
local current_day = 0
local current_hour = 0
local current_minute = 0

local check_cron = {
	-- curtime 是当前时间的秒数
	interval = function(cron_ini, curtime)
		return curtime % cron_ini.timer < 5
	end,
	fixed = function(cron_ini, curtime)
		-- 检查当前时间是否符合设定的小时、分钟、日期或星期要求
		if
			current_hour == cron_ini.hour
			and current_minute == cron_ini.minute
			and curtime - cron_ini.last_execute_time > 100
		then
			if cron_ini.day > 0 and current_day == cron_ini.day then
				return true
			elseif cron_ini.week > 0 and current_week == cron_ini.week then
				return true
			end
		end
		return false
	end,
}

local check_config = function()
	local curtime = math.floor(ngx.now())
	current_week = tonumber(os.date("%w", curtime)) + 0
	current_day = tonumber(os.date("%d", curtime)) + 1
	current_hour = math.floor((curtime + 28800) % 86400 / 3600) --  UTC+8
	current_minute = math.floor(curtime % 3600 / 60)

	for appname, conf_list in pairs(app.cron_conf) do
		for id, conf in pairs(conf_list) do
			if check_cron[conf.timer_type](conf, curtime) then
				redis:rpush("statistics:job:execute", appname .. ":" .. id)
				redis:set("statistics:timer:fixed:lasttime:" .. appname .. ":" .. id, curtime)
			end
		end
	end
end

local init_cron = function()
	local manager = redis:get("statistics:job:cron:manager")
	if manager then
		return
	end

	local rs = redis:setnx("statistics:job:cron:manager", 1)
	if tonumber(rs) ~= 1 then
		return
	end
	redis:setex("statistics:job:cron:manager", 10, 1)
	ngx.timer.every(5, function()
		redis:setex("statistics:job:cron:manager", 10, 1)
		check_config()
	end)
end

local function do_execute()
	local retry_num = 0
	while not worker.killed do
		local task = redis:blpop("statistics:job:execute", 10)
		if task and task[2] then
			local keys = str_split(task[2], ":")
			if keys and #keys == 2 then
				local appname, id = keys[1], keys[2]
				local c = app.cron_conf[appname][id]
				if c then
					app.thread_statistics:add(c.exec)
				end
			end
		else
			if retry_num > 5 then
				break
			end
			ngx.sleep(1)
			retry_num = retry_num + 1
		end
	end

	if not worker.killed then
		core.go(0, do_execute)
	end
end

local _M = {}

_M.remove = function(appname, id)
	id = tostring(id)
	if app.cron_conf[appname] then
		app.cron_conf[appname][id] = nil
	end
end

_M.append = function(appname, id, script)
	id = tostring(id)
	local tmp = {}
	tmp.timer_type = script.timer_type
	tmp.timer = script.timer
	tmp.day = script.day
	tmp.week = script.week
	tmp.hour = script.hour
	tmp.minute = script.minute
	tmp.func = script.func
	tmp.appname = appname
	tmp.id = id

	local func = tmp.func
	tmp.exec = function()
		local stat = statistics.new(appname)
		stat.script_id = tostring(id)
		local t1 = now()
		local ok, ret1, ret2 = pcall(func, stat)
		if not ok then
			logerr("execute cron script_failed error appname =  ", appname, " ,script_id =  ", id)
		else
			if ret1 then
				loginfo("execute cron success appname = ", appname, " ,script_id =  ", id)
			else
				logerr("execute cron return_error appname = ", appname, ", script_id =  ", id, ",error = ", ret2)
			end
		end

		local logdata = {
			date = now_date("%Y-%m-%d %H:%M:%S"),
			script_id = id,
			ok = ok,
			ret1 = ret1 or "",
			ret2 = ret2 or "",
			execution_time = now() - t1,
		}

		local k = "statistics:log-watch:" .. appname
		stream:publish(k, encode(logdata))
		local k_script_id = "statistics:log-watch:" .. appname .. ":" .. id
		stream:publish(k_script_id, encode(logdata))
	end

	if tmp.timer_type == "fixed" then
		tmp.last_execute_time = redis:get("statistics:timer:fixed:lasttime:" .. appname .. ":" .. id)
		if not tmp.last_execute_time then
			tmp.last_execute_time = 0
		end
	end

	app.cron_conf[appname] = app.cron_conf[appname] or {}
	app.cron_conf[appname][id] = tmp
end

_M.run = function()
	core.go(0, do_execute)
	ngx.timer.every(5, function()
		init_cron()
	end)
end

return _M
