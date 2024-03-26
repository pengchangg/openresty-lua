--[[
实体对象
--]]
local semaphore = require "ngx.semaphore"
local sleep = ngx.sleep
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local kill = ngx.thread.kill
local update_time = ngx.update_time
local now = ngx.now

local _M = {_VERSION = '0.01'}

local mt = { __index = _M }

function _M:new(id,ty,heart)
	if not id then return false,'no id' end
	
	return setmetatable({
        messages = {},
		heart = heart or 1,
		sema = semaphore:new(),
		id = id,
		type = ty,
		threads = {
			sema = semaphore:new(),
			timer = false,
			idx = 0,
			handles = {},
			opers = {},
		},
    }, mt)
	
end

local _do_opers_thread = function(self)
	while not self.kill do
		update_time()
		local curtime = now()
		for _,oper in ipairs(self.threads.opers) do
			local sid = spawn(function()
				sleep(0.001) -- 后执行
				oper.fun(curtime,oper.id,oper.data)
				self.threads.handles[oper.id] = nil
			end)
			self.threads.handles[oper.id] = sid
		end
		self.threads.opers = {}

		self.threads.sema:wait(300)
	end
end

local _process_message_thread = function(self)
	while not self.kill do
		local msgs = self.messages
		local total = #msgs
		
		self.messages = {}
		for i = 1,total do
			self.on_message(self,msgs[i])
			sleep(0.001)
		end

		self.sema:wait(300)
	end
end

local _process_heart_thread = function(self)
	local heart = 1
	while not self.kill do
		heart = heart + 1
		self.on_heart(self,heart)
		
		sleep(self.heart)
	end
end

function _M:init(on_message,on_heart,on_destroy)
	self.on_message = on_message
	self.on_heart = on_heart
	self.on_destroy = on_destroy
	
	self.threads.timer = spawn(_do_opers_thread,self)
	
	if self.on_message then 
		self.thread_on_message = spawn(_process_message_thread,self)
	end
	if self.on_heart then 
		self.thread_heart = spawn(_process_heart_thread,self)
	end
	
	return true
end

function _M:append_message(head,data)
	if self.kill then return false,'The entity has been destroyed' end
	if not data then
		data = head
		head = nil
	end
	self.messages[#self.messages + 1] = {head = head,data = data}
	self.sema:post(1)
end

function _M:append_thread(operfun,operdata)
	self.threads.idx = self.threads.idx + 1
	if self.threads.idx > 999999 then self.threads.idx = 1 end
	
	self.threads.opers[#self.threads.opers + 1] = {
		id = self.threads.idx,
		fun = operfun,
		data = operdata
	}
	self.threads.seam:post(1)
	return self.threads.idx
end

function _M:delete_thread(thread_id)
	if thread_id and self.threads.handles[thread_id] then
		kill(self.threads.handles[thread_id])
	end
end

function _M:destory(code,waitforthreads)
	self.kill = true
	
	if self.sema then
		self.sema:post(1)
	end
	
	if self.threads.sema then
		self.threads.sema:post(1)
	end
		
	if waitforthreads and not worker.killed then
		for _,v in ipairs(self.threads.handles) do
			wait(v)
		end
		
		if self.thread_on_message then
			wait(self.thread_on_message)
		end
		
		if self.threads.timer then
			wait(self.threads.timer)
		end
		
		
		if self.thread_heart then
			wait(self.thread_heart)
		end
	end
	
	if self.on_destroy then
		self.on_destroy(self,code)
	end
end

return _M