--[[
缓存加载
--]]
local tostring = tostring
local resty_lock = require "resty.lock"
local mlcache = require 'resty.mlcache'
local config = config
local clone = require 'core.clone'

local _M = {version = 0.1}

--加锁
local _do_lock = function(lock_shm,key)
	local lock,err = resty_lock:new(lock_shm)
	if not lock then return nil,err end
	
	local _,err = lock:lock(key)
	if err then return nil,err end
	
	return lock
end

--获取函数方法
local _get_function = function(path)
	if not path then return nil end
	if type(path) == 'function' then return path end
	
	local ok,fun = pcall(require,path)
	if ok and type(fun) == 'function' then
		return fun
	end

	core.log.error('[ERROR] load model failed -> ', path)
	return nil
end

--创建数据获取方法
local make_get_from_db_function = function(opts)
	if not opts.get_from_db then return nil end

	opts.get_from_db = _get_function(opts.get_from_db)
	if opts.get_from_db then
		return function(key)
			return opts.get_from_db(opts,key)
		end
	end
	
	return nil
end

--创建数据保存方法
local make_save_to_db_function = function(opts)
	if not opts.save_to_db then return nil end

	opts.save_to_db = _get_function(opts.save_to_db)
	if opts.save_to_db then
		return function(key,value,newdata)
			return opts.save_to_db(opts,key,value,newdata)
		end
	end

	return nil
end

--从缓存中获取数据
local _get = function(self,key,copy,nolock,onlyfromcache)
	key = tostring(key)
	--更新缓存
	self.cache:update(key)
	
	if not nolock and self.opts.read_lock_on then
		local lock,err = self.opts.do_lock('data:set:lock:' .. key)
		if lock then
			lock:unlock()
		end
	end
	
	local cb_get_from_db = self.get_from_db
	if onlyfromcache then cb_get_from_db = nil end
	
	--获取缓存值
	local value,err,hitlevel = self.cache:get(key,self.opts,cb_get_from_db,key)
	if err then
		return nil,'get value failed. err = ' ..err
	end
	
	if not value then return value end
	--如果要求复制，则返回副本
	if copy then
		return clone(value)
	else
		return value
	end
end

--批量获取缓存值
local _get_bulk = function(self,bulk)
	for i = 3,bulk.n,4 do
		bulk[i] = bulk[i] or self.get_from_db
		bulk[i + 1] = bulk[i + 1] or bulk[i - 2]
	end

	return self.cache:get_bulk(bulk,{concurrency = self.opts.concurrency})
end

--创建批量获取列表
local _new_bulk = function(self,n_lookups)
	return mlcache.new_bulk(n_lookups)
end

--批量获取的缓存值列表遍历方法
local _each_bulk_res = function(self,res)
	return mlcache.each_bulk_res(res)
end

--touch缓存，判定缓存是否存在
local _peek = function(self,key)
	key = tostring(key)
	return self.cache:peek(key)
end

--设置缓存值
local _set = function(self,key,value,copy)
	if value == nil then
		return self:delete(key)
	end
	
	key = tostring(key)
	local lock,err = self.opts.do_lock('data:set:lock:' .. key)
	if not lock then
		return false,'add lock failed ->' .. err
	end
	
	local oldvalue = self:get(key,false,true,true)

	--先保存到数据库
	if self.save_to_db then
		local err = false
		--保存
		key,value,err = self.save_to_db(key,oldvalue,value)
		if err then
			lock:unlock()
			return false,err
		end
	end
	
	--再保存到缓存，并通知其他work
	if copy then value = clone(value) end
	local ok,err = self.cache:set(key,self.opts,value)
	
	lock:unlock()

	--返回key
	if not ok then
		return false,err
	else
		return key
	end
end

--更新缓存值
local _update = function(self,key,newdata)
	if newdata == nil then return false,'wrong new data' end
	
	if type(newdata) ~= 'table' then
		return self:set(key,newdata)
	end
	
	key = tostring(key)
	local lock,err = self.opts.do_lock('data:set:lock:' .. key)
	if not lock then
		return false,'add lock failed ->' .. err
	end
	
	local oldvalue = self:get(key,false,true,true)
	if oldvalue == nil then
		lock:unlock()
		return false,'this data is not exist.'
	end
	
	if type(oldvalue) ~= 'table' then
		lock:unlock()
		return self:set(key,newdata)
	end

	local value = nil
	--先保存到数据库
	if self.save_to_db then
		--保存
		key,value,err = self.save_to_db(key,oldvalue,newdata)
		if err then
			lock:unlock()
			return false,err
		end
	else
		value = oldvalue
		for k,v in pairs(newdata) do
			value[k] = v
		end
	end
	
	--再保存到缓存，并通知其他work
	local ok,_ = self.cache:set(key,self.opts,value)
	
	lock:unlock()
	return ok
end

--删除缓存
local _delete = function(self,key)
	key = tostring(key)
	return self.cache:delete(key)
end

--清空缓存
local _purge = function(self,flush_expired)
	return self.cache:purge(flush_expired)
end

local _new_cache = function (name, conf)
	--缓存同步字典对象
	conf.shm_miss = conf.shm_miss or 'sys_cache_miss'
	conf.shm_locks = conf.shm_locks or 'sys_cache_locks'
	if not conf.ipc_redis and not conf.ipc then
		--conf.ipc_shm = conf.ipc_shm or 'sys_cache_ipc'
		conf.ipc_shm = conf.ipc_shm or ('sys_cache_ipc_' .. name)
	end
	
	conf.debug = config and config.debug
	
	conf.do_lock = conf.do_lock or function(lock_key)
		return _do_lock(conf.shm_locks,lock_key)
	end

	--反序列化方法
	conf.l1_serializer = _get_function(conf.l1_serializer)
	
	local cache = {
		cache = mlcache.new(name,name,conf),
		opts = conf,
		get_from_db = make_get_from_db_function(conf),
		save_to_db = make_save_to_db_function(conf),
		get = _get,
		get_bulk = _get_bulk,
		new_bulk = _new_bulk,
		each_bulk_res = _each_bulk_res,
		peek = _peek,
		set = _set,
		delete = _delete,
		purge = _purge,
		update = _update,
	}

	return cache
end

_M.new = _new_cache

--缓存对象列表
if config and config.caches then
	for k,v in pairs(config.caches or {}) do
		_M[k] = _new_cache(k,v)
	end
end

return _M