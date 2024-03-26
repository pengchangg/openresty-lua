local s_find = string.find
local s_sub = string.sub
local t_insert = table.insert
local new_table = require 'core.table'.new
local ceil = math.ceil

--将hash表的key值转换为number类型输出
local _M = function(str,p,ismatch)
	local maxlen = ceil(#str / 2)
	local ret = new_table(maxlen,0)

	local idx = 1
	local prefindidx = 1

	local s,e = s_find(str,p,prefindidx,not ismatch)
	while s do
		local s1 = s_sub(str,prefindidx,s-1)
		if #s1 > 0 then
			ret[idx] = s1
			idx = idx + 1
		end

		prefindidx = e + 1
		s,e = s_find(str,p,prefindidx,not ismatch)
	end

	if #str >= prefindidx then
		ret[idx] = s_sub(str,prefindidx)
	end

	return ret
end

return _M