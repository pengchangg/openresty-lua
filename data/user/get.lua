local decode = core.cjson.decode
local str_split = core.string.split
---@diagnostic disable-next-line: undefined-field
local redis = db.redis

local _M = function(_, key)
	local keys = str_split(key, ":")
	if not keys or #keys < 2 then
		return nil
	end

	local ret, err = redis:hgetall("statistics:user:attr:" .. key)

	if err ~= nil then
		return nil
	end

	if #ret > 0 then
		return ret
	end

	local appname = keys[1]
	local userid = keys[2]
	local tablename = "sys_user_" .. appname

	local sql = "select attribute from `%s` where userid = '%s'"
	sql = string.format(sql, tablename, userid)
	---@diagnostic disable-next-line: undefined-field
	ret, err = db.mysql:query(sql)

	if err ~= nil then
		return nil
	end

	if #ret > 0 then
		return decode(ret[1].attribute)
	end

	return nil
end

return _M
