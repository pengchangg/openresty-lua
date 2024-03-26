---@diagnostic disable-next-line: undefined-field
local redis = db.redis
local str_split = core.string.split
local _M = {}

local function arrayToKeyValue(array)
	if type(array) == "nil" or #array < 2 then
		return {}
	end
	local result = {}
	for i = 1, #array, 2 do
		result[array[i]] = array[i + 1]
	end
	return result
end

_M.statistics_event_num = function(appname, event_id)
	local key = string.format("statistics:event_num:%s:%s", appname, event_id)
	local field_datetime = os.date("%Y%m%d")
	return redis:hincrby(key, field_datetime, 1)
end

_M.get_statistics_event_num = function(appname, event_id)
	local ret = {}
	local key = string.format("statistics:event_num:%s:%s", appname, event_id)

	local data, _ = redis:hgetall(key)
	ret[event_id] = arrayToKeyValue(data)
	return ret
end

_M.get_statistics_event_num_all = function(appname)
	local key = string.format("statistics:event_num:%s:*", appname)
	local data = {}
	local keys, _ = redis:keys(key)

	for _, k in ipairs(keys or {}) do
		local tmp_data, _ = redis:hgetall(k)

		local k_array = str_split(k, ":")
		data[k_array[#k_array]] = arrayToKeyValue(tmp_data)
	end

	return data
end

return _M
