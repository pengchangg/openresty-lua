local ngx_thread_spawn = ngx.thread.spawn
local ngx_thread_wait = ngx.thread.wait
local semaphore = require "ngx.semaphore"

local core_table = require 'core.table'
local new_table = core_table.new
local del_table = core_table.release

local tpool = require 'core.thread.pool'
local default_pool = nil

local _M = {version = 0.1}
local mt = {__index = _M}

_M.new = function(self,pool)
	if not pool then
		if not default_pool then
			default_pool = tpool:new(1000)
			core.go(0,function ()
				default_pool:run()
			end)
			ngx.sleep(0.001)
		end
		pool = default_pool
	end

	local m = {
		pool = pool,
		total = 0,
		finished = 0,
		sema = semaphore:new()
	}
	
	return setmetatable(m,mt)
end

local _do_worker = function (self,fun,...)
	local ok,err = pcall(fun,...)
	if not ok then
		core.log.error('do worker in group failed. -> ', err or 'unkonwn')
	end
	self.finished = self.finished + 1
	if self.finished >= self.total then
		self.sema:post(1)
	end
end

_M.add = function(self,fun,...)
	self.total = self.total + 1
	if not self.pool:add(_do_worker,self,fun,...) then
		_do_worker(self,fun,...)
	end
	return self.total
end

_M.wait = function(self)
	while self.finished < self.total do
		self.sema:wait(30)
	end

	self.total = 0
	self.finished = 0
end

return _M