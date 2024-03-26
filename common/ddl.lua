local _M = {}
local tablename = "sys_table_ddl"
---@diagnostic disable-next-line: undefined-field
local mysql = db.mysql

local function contains_sensitive_operation(ddl)
	ddl = string.lower(ddl)
	local sensitive_keywords = { "drop", "truncate", "modify", "change", "rename" }

	for _, keyword in ipairs(sensitive_keywords) do
		if string.match(ddl, "^%s*" .. keyword .. "%s") then
			return true
		end
	end

	return false
end

local function replace_table_name(ddl_str, appname)
	ddl_str = string.lower(ddl_str)
	local old_table_name = ddl_str:match("create table%s+(%S+)")

	if not old_table_name then
		old_table_name = ddl_str:match("alter table%s+(%S+)")
	end

	if not old_table_name then
		return nil
	end

	local new_table_name = "t_" .. old_table_name .. "_" .. appname

	if old_table_name then
		local pattern = old_table_name:gsub("(%p)", "%%%1")
		local replaced_ddl = ddl_str:gsub(pattern, new_table_name)

		return replaced_ddl
	else
		return nil
	end
end

local function check_ddl(appname, ddl)
	if contains_sensitive_operation(ddl) then
		return false, 503, "ddl 中只能有建表或者增加字段的操作语句.1"
	end

	local new_ddl = replace_table_name(ddl, appname)
	if not new_ddl then
		return false, 503, "ddl 中只能有建表或者增加字段的操作语句.2"
	end

	return new_ddl
end

function _M.get(appname)
	local sql = string.format("select * from `%s` where `appname` = '%s' and verify > 0   ", tablename, appname)
	return mysql.query(sql)
end

function _M.get_table(appname)
	local database_name = "zx_dataanalysis_statistics"
	local select_table_sql = string.format('SHOW TABLES FROM %s LIKE "%%_%s"', database_name, appname)
	core.log.error("get_table ---> select_table_sql:", select_table_sql)
	local table_list, err = mysql:query(select_table_sql)

	local create_table_ddl = {}

	for _, value in pairs(table_list or {}) do
		for _, table_name in pairs(value) do
			local select_create_table_sql = string.format("SHOW CREATE TABLE  %s", table_name)
			local table_ddl, err = mysql:query(select_create_table_sql)
			table.insert(create_table_ddl, table_ddl[1])
		end
	end

	return create_table_ddl, err
end

function _M.sync_create_table(ddl_list)
	for _, ddl in ipairs(ddl_list) do
		---@diagnostic disable-next-line: undefined-field
		db.mysql:query(ddl)
	end
end

_M.check = check_ddl
function _M.exec(appname, ddl, remark)
	ddl = string.lower(ddl)

	local ddl, _, err = check_ddl(appname, ddl)
	if not ddl then
		return false, err
	end

	---@diagnostic disable-next-line: undefined-field
	local ret, err = db.mysql:query(ddl)

	if not ret then
		core.log.error("ddl执行失败日志----->", err)
	end
	err = err or "success"

	local sql = "insert into `sys_table_ddl` (`appname`,`ddl`,`exec_outin`,`remark`) values ('%s',%s,%s,'%s')"
	sql = string.format(sql, appname, ngx.quote_sql_str(ddl), ngx.quote_sql_str(err), remark or "")

	---@diagnostic disable-next-line: undefined-field
	return db.mysql:query(sql)
end

return _M
