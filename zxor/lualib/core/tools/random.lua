local math_random = math.random
local math_randomseed = math.randomseed
local random_seed = 0
local random_seed_in = 0.001


---#args == 0 =====>随机[0,1)区间的实数
---#args == 1 
---		type(args[1])=="number" =====>随机[1,args[1]]区间的整数
---		type(args[1])=="array table"([1,2,3,...n],至少需要有两个元素) =====>随机取出args[1]数组中的一个元素
---		type(args[1])=="hash table"([key1=1,key2=2,key3=3,...keyn=n],key值必须为正整数,需要注意与array table区别，如果无法区别，请使用两个参数) 
---			=====>根据key值大小决定获取几率取出args[1]表中的一个元素
---#args == 2 =====>随机[args[1],args[2]]区间的整数
---		type(args[1])=="number"
---		---		type(args[2])=="number" =====>随机[args[1],args[2]]区间的整数
---		---		type(args[2])=="hash table" =====>根据key值大小决定获取几率取出args[2]表中的一个元素,如果args[1] ~= 0则表示为hash表key合值
---		type(args[1])=="array table"([[],[],[],...[]]) and type(args[2])=="number" or "string" 
---				=====>args[1]为二维数组，args[2]为第二维数组作为几率计算值的key，根据指定几率值大小决定获取几率取出args[1]表中的一个元素
local _M = function(...)
	local args = {...}
	local n = #args
	if n > 2 then return false end
	local cur_random_seed = ngx.now()
	if cur_random_seed == random_seed then 
		cur_random_seed = random_seed + random_seed_in
		random_seed_in = random_seed_in + 0.001
	else
		random_seed = cur_random_seed
		random_seed_in = 0.001
	end
	math_randomseed(cur_random_seed)
	
	if n == 0 then
		return math_random()
	elseif n == 1 then
		local typ = type(args[1])
		if typ == "number" then
			return math_random(1,args[1])
		elseif typ == "table" then
			if args[1][1] and args[1][2] then
				return args[1][math_random(1,#args[1])]
			else
				local m = 0
				for k,v in pairs(args[1]) do
					m = m + k
				end
				local r = math_random(1,m)
				for k,v in pairs(args[1]) do
					if r <= k then return v end
					r = r - k
				end
			end
		end
	elseif n == 2 then
		local t1,t2 = type(args[1]),type(args[2])
		if t1 == "number" then
			if t2 == "number" then return math_random(args[1],args[2]) end
			if t2 == "table" then
				if args[1] <= 0 then
					for k,v in pairs(args[2]) do
						args[1] = args[1] + k
					end
				end
				local r = math_random(1,args[1])
				for k,v in pairs(args[2]) do
					if r <= k then return v end
					r = r - k
				end
			end
		elseif t1 == "table" then
			local m = 0
			for i,v in ipairs(args[1]) do
				if v[args[2]] then
					m = m + tonumber(v[args[2]])
				end
			end
			local r = math_random(1,m)
			for i,v in ipairs(args[1]) do
				if v[args[2]] then
					local k = tonumber(v[args[2]])
					if r <= k then return v end
					r = r - k
				end
			end
		end
	end
	
	return false
end

return _M