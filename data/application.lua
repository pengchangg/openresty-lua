local str_split = core.string.split

---@diagnostic disable-next-line: undefined-field
local mysql = db.mysql
---@diagnostic disable-next-line: undefined-field
local stream = db.redis

local logerr = core.log.error
---@diagnostic disable-next-line: undefined-field
local random = require("zxor.lualib.core.tools.random")

local _M = {}
local watch_application_change_channel = "statistics:application:subscribe:changed"

local function generate_random_string(length)
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	math.randomseed(random(100000000, 999999999) + 0)
	local random_string = ""

	for _ = 1, length do
		local random_index = math.random(#charset)
		random_string = random_string .. string.sub(charset, random_index, random_index)
	end

	return random_string
end

local function check_app_tables(appname)
	local tablename = "sys_user_" .. appname
	local create_table_sql = string.format("create table if not exists %s like sys_user_0 ", tablename)
	return mysql:query(create_table_sql)
end

local function preprocessing(verify, appname)
	local select_sql = string.format("select `secret` from `sys_app` where appname = '%s'  ", appname)
	local ret, err = mysql:query(select_sql)

	if err or #ret == 0 then
		logerr("require application failed -> ", err or "unknown")
		return nil
	end

	local secret = ret[1].secret

	local is_del = 0

	if verify > 0 then
		-- 检查sys_user_{appname}  表是否创建，没有则创建,通知更新内存中的 appid-secret
		check_app_tables(appname)
	else
		is_del = 1
	end

	stream:publish(watch_application_change_channel, string.format("%s:%s:%d", appname, secret, is_del))

	return true
end

function _M.add(args, headers)
	local appname = args.appname
	local id = tonumber(args.id) or 0
	local verify = args.verify or 0
	local remark = args.remark or ''

	local msg, status = "ok", 0

	local sql = ""

	if id > 0 then
		if verify > 0 then
			verify = 1
		end

		local format_str = ""
		if args.appname then
			format_str = string.format(' appname = "%s",remark = "%s" , verify = %d', args.appname, remark, verify)
		else
			format_str = string.format(" verify = %d ", verify)
		end

		if string.len(format_str) > 0 then
			sql = " update  `sys_app` set  %s where id = %s "
			sql = string.format(sql, format_str, id)

			---@diagnostic disable-next-line: undefined-field
			local ret, error_msg = db.mysql:query(sql)

			if not ret then
				status = 502
				msg = error_msg
			else
				-- 数据库更新成功 根据verify进行预处理
				preprocessing(verify, appname)
			end
		end
	else
		local secret = generate_random_string(32)

		sql = "insert into `sys_app` (`appname`,`secret`,`remark`,`verify`) values ('%s','%s','%s',%d)"
		sql = string.format(sql, appname, secret, remark, verify)
		---@diagnostic disable-next-line: undefined-field
		local ret, error_msg = db.mysql:query(sql)
		if not ret then
			status = 502
			msg = error_msg
		end
	end

	return msg, status
end

local load_application = function(appname, secret, is_del)
	if is_del == "1" then
		app.application[appname] = nil
	else
		app.application[appname] = secret
	end
end

local watch_script_change = function()
	core.go(0, function()
		stream:subscribe(watch_application_change_channel, function(key)
			local keys = str_split(key, ":")
			local appname, secret, is_del = keys[1], keys[2], keys[3]
			load_application(appname, secret, is_del)
		end)
	end)
end

local load_all_application = function()
	core.go(0, function()
		local sql = "select `appname`,`secret` from  `sys_app` where verify > 0"
		---@diagnostic disable-next-line: undefined-field
		local ret, error = db.mysql:query(sql)
		if not error and #ret > 0 then
			for _, app in ipairs(ret) do
				load_application(app.appname, app.secret, 0)
			end
		end
	end)
end

_M.init = function()
	load_all_application()
	watch_script_change()
end

_M.get = function(appname, secret, is_del)
	return load_application(appname, secret, is_del)
end

return _M
