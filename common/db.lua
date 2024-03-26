local _M = {}

_M.updae_db = function(tablename, data, condition)
	local set = {}
	for key, value in pairs(data) do
		table.insert(set, string.format("%s = %s", key, ngx.quote_sql_str(value or "")))
	end

	local sql = string.format("update %s set %s  where %s ", tablename, table.concat(set, ", "), condition)

	---@diagnostic disable-next-line: undefined-field
	return db.mysql:query(sql)
end

_M.get = function(tablename, condition)
	local select_sql = string.format("select * from `%s` ", tablename)
	if condition then
		select_sql = select_sql .. " where " .. condition
	end

	core.log.info("select_sql = ", select_sql)

	---@diagnostic disable-next-line: undefined-field
	return db.mysql:query(select_sql)
end

_M.insert_db_return_last_id = function(tablename, data)
	local fields = {}
	local values = {}

	for key, value in pairs(data) do
		table.insert(fields, key)
		table.insert(values, ngx.quote_sql_str(value))
	end

	local sql = string.format(
		"INSERT INTO %s (%s) VALUES (%s)",
		tablename,
		table.concat(fields, ", "),
		table.concat(values, ", ")
	)

	---@diagnostic disable-next-line: undefined-field
	local ok, err = db.mysql:query(sql)

	if not ok then
		return false, err
	end

	local select_last_sql = string.format("select `id` from %s order by id desc limit 1 ", tablename)

	---@diagnostic disable-next-line: undefined-field
	local ret, err = db.mysql:query(select_last_sql)
	if err and #ret > 0 then
		return false, err
	end

	return ret[1].id, nil
end
return _M
