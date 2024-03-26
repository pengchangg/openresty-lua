--[[
worker内部缓存
--]]
local sleep = ngx.sleep
local now = ngx.time

local clone = require 'core.clone'
local go = require 'core.go'
local tab = require 'core.table'

local newtab = tab.new
local deltab = tab.release

--缓存数据
--分开保存，是为了便于过期缓存的清除
local data_t = newtab(0,1000)		--记录缓存过期的时间戳
local data_v = newtab(0,1000)		--以时间戳为索引的缓存集合
local st = now()

--清除过期缓存
local clear = nil
clear = function()
	local et = now()
	local n = 0
	--按时间点逐点清除
	for t = st,et do
		if data_v[t] then
			--存在缓存
			for k,_ in pairs(data_v[t]) do
				n = n + 1
				data_t[k] = nil
				if n >= 1000 then
					n = 0
					sleep(0.1)
				end
			end
			deltab(data_v[t])
			data_v[t] = nil
		end
	end
	st = et
	
	go(300,clear)
end

local _M = {}

_M.get = function(k,copy)
	local t = data_t[k]
	--没有找到对应的时间戳，无缓存
	if not t then return nil end
	--时间戳过期
	if t > 0 and t < now() then
		-- 清除过期数据
		data_t[k] = nil
		return nil
	end
	--缓存数据出现错误，更新状态
	if not data_v[t] then
		data_t[k] = nil
		return nil
	end
	--返回缓存或缓存副本
	if copy then
		return clone(data_v[t][k])
	else
		return data_v[t][k]
	end
end

--
_M.set = function(k,v,outtime,copy)
	--清除原缓存记录
	_M.del(k)
	if v == nil then
		return true
	end

	--过期时间，0表示永不过期
	local t = outtime or 0
	if t > 0 then
		t = now() + t
	end

	--记录新缓存
	data_t[k] = t
	if not data_v[t] then
		data_v[t] = newtab(0,10,'core.inner.cache.tab')
		data_v[t].__length = 0
	end
	if copy then
		data_v[t][k] = clone(v)
	else
		data_v[t][k] = v
	end

	-- 维护缓存大小
	data_v[t].__length = data_v[t].__length + 1

	return true
end

--删除缓存
_M.del = function(k)
	local t = data_t[k]
	data_t[k] = nil
	if t and data_v[t] then
		-- 维护缓存大小
		if data_v[t][k] ~= nil then
			data_v[t].__length = data_v[t].__length - 1
		end
		data_v[t][k] = nil

		if data_v[t].__length <= 0 then
			deltab(data_v[t])
			data_v[t] = nil
		end
	end
	return true
end

--启动缓存清理协程
_M.open_clear = function()
	go(300,clear)
end

return _M
