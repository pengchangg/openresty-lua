--[[
mysql 便捷接口
--]]
local ngx = ngx
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local semaphore = require "ngx.semaphore"
local sleep = ngx.sleep
local mysql = require 'core.mysql.mysql'

local t_remove = table.remove

local _M = {}

local cons = {}

--sql执行
local query = function(config,sql)
	local con = mysql:new(config.host,config.port,config.user or config.username,config.password,config.database,config.charset)
	local retry = 0
	local rs,err = con:open()
	if rs then
		rs,err = con:query(sql)
		if err then
			core.log.info('query failed. -> ',err)
		end
	end
	con:close()
	return rs,err
end

--创建新的mysql对象
local new_con = function(config)
	return mysql:new(config.host,config.port,config.user or config.username,config.password,config.database,config.charset)
end

--创建mysql对象池
local make_pool = function(config)
	local con = {
		inuse = 0,
		conf = config,
		concurrency = config.concurrency or 100,
		sema = semaphore:new(),
		pool = {},
		free = {},
	}

	if config.concurrency then
		con.get_connect = function(self)
			while true do
				if #self.free > 0 then return t_remove(self.free,1) end
				if #self.pool < self.concurrency then
					self.pool[#self.pool + 1] = new_con(self.conf)
					self.inuse = self.inuse + 1
					self.pool[#self.pool].idx = self.inuse
					return self.pool[#self.pool]
				end
				self.sema:wait(10)
			end
		end
		
		con.reback_connect = function(self,connect)
			self.free[#self.free + 1] = connect
			connect:close()
			self.sema:post(1)
		end
		
		con.remove_connect = function(self,connect)
			local idx = nil
			for i,v in ipairs(self.pool) do
				if v == connect then 
					idx = i
					break 
				end
			end
			if idx then
				t_remove(self.pool,idx)
			end
			connect:close(true)
			self.sema:post(1)
		end
		
		con.query = function(self,sql)
			local dbcon = self:get_connect()
			local rs = nil
			local err = 'can not get free connect.'
			if dbcon then
				rs,err = dbcon:query(sql)
				--core.log.info('use dbcon -> ',dbcon.idx,' state = ',dbcon.con and dbcon.con.sock:getreusedtimes() or 0)
				if err then
					--core.log.info('dbcon err = ',err)
					self:remove_connect(dbcon)
				else
					self:reback_connect(dbcon)
				end
			end

			return rs,err
		end
	else
		con.get_connect = function(self)
			return new_con(self.conf)
		end
	
		con.reback_connect = function(self,connect)
			connect:close()
		end
		
		con.remove_connect = function(self,connect)
			connect:close(true)
		end
		
		con.query = function(self,sql)
			return query(self.conf,sql)
		end
	end
	
	return con
end

--执行sql
_M.query = function(config,sql)
	if not config.user and config.username then
		config.user = config.username
	end
	if not config.host or not config.port or not config.user or not config.database then return false,'wrong params' end

	if not config.concurrency or config.concurrency <= 0 then
		return query(config,sql)
	end
	
	local key = config.host .. config.port .. config.user .. config.database 
	
	if not cons[key] then
		cons[key] = make_pool(config)
	end
	
	return cons[key]:query(sql)
end

--获取一个mysql对象
_M.get_single_con = new_con
--获取mysql池
_M.get_con_pool = make_pool

return _M