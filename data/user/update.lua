local encode = core.cjson.encode
local decode = core.cjson.decode

---@diagnostic disable-next-line: undefined-field
local redis = db.redis

local _M = function(_, key, olddata, newdata)
	local splitIndex = key:find(":")
	local appname = key:sub(1, splitIndex - 1) -- 提取第一个部分
	local userid = key:sub(splitIndex + 1) -- 提取第二个部分

	for k, v in pairs(newdata) do
		if type(v) == "table" then
			v = encode(v)
		end
		local _, err = redis:hset("statistics:user:attr:" .. key, k, v)
		if err then
			return key, olddata, err
		end
	end
	local tablename = "sys_user_" .. appname

	-- 需要检查新增还是更新
	local sql = "select `attribute` from `%s` where userid = '%s'"
	sql = string.format(sql, tablename, userid)
	---@diagnostic disable-next-line: undefined-field
	local ret, err = db.mysql:query(sql)

	if err == nil and #ret < 1 then
		-- insert
		sql = "insert into %s (userid,attribute) values ('%s',%s)"
		sql = string.format(sql, tablename, userid, ngx.quote_sql_str(encode(newdata)))
	else
		local attribute = decode(ret[1].attribute)
		for k, v in pairs(newdata) do
			attribute[k] = v
		end
		-- update
		sql = "update %s set attribute = %s where  userid = '%s'"
		sql = string.format(sql, tablename, ngx.quote_sql_str(encode(attribute)), userid)
		newdata = attribute
	end

	---@diagnostic disable-next-line: undefined-field
	ret, err = db.mysql:query(sql)
	if not err then
		return key, newdata
	end

	return key, newdata
end

return _M
