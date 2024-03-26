--[[
websocket方法集
--]]
local sleep = ngx.sleep
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local kill = ngx.thread.kill

local errlog = require 'core.log'.error
local Server = require "resty.websocket.server"
local Client = require "resty.websocket.client"
local semaphore = require "ngx.semaphore"

local t_remove = table.remove
local t_insert = table.insert
local t_concat = table.concat

local str_find = string.find

local newtable = require 'core.table'.new
local cleartable = require 'core.table'.clear
local deltable = require 'core.table'.release

local _M = {}
_M._VERSION = '0.01'

local get_one_msg_obj = function(content,ty)
	local msg = newtable(0,2,'wsmsg')
	msg.content = content
	msg.ty = ty or type(content)

	return msg
end

--发送消息
--主动发送的消息中，没有ping pong消息
local function send(self,content,ty)
	local bytes, err = true, nil
	if ty == "close" then
		if content.code == 0 then
			if self.on_close then
				self.on_close(self,self.close_reason,self.close_code)
			end
			self.conn.fatal = true
		elseif self.conn and not self.conn.fatal then
			self.conn:send_close(content.code, content.reason or content.code)
		end
	elseif self.conn and not self.conn.fatal then
		if ty == "string" or ty == "number" then
			bytes,err = self.conn:send_text(content)
		else
			bytes,err = self.conn:send_binary(content)
		end
	end
	
	--core.log.info('send message -> ',ty, ' -- err = ',err)

	return bytes,err
end

--推送消息
local function push(self)
	if self.push_msgs.count == 0 then return end

	local n = 0
	for i = self.push_msgs.idx,self.push_msgs.count do
		local msg = self.push_msgs[i]
		local bytes,err = send(self,msg.content,msg.ty)
		if not bytes then return end
		self.push_msgs.idx = self.push_msgs.idx + 1
		deltable(msg)
		n = n + 1
		--防止消息过多，独占进程cpu，每发5个消息暂停一次
		if n == 500 then
			--sleep(0.001)
			n = 0
		end
	end

	cleartable(self.push_msgs)
	self.push_msgs.count = 0
	self.push_msgs.idx = 1
end

--推送消息协程
local function push_thread(self)
	while not self.killed do
		if not self.conn or self.conn.fatal then return end
		--先发送推送消息列表中的消息
		if self.push_msgs.count >= self.push_msgs.idx  then
			push(self)
		elseif self.messages.count > 0 then
			--将消息列表转移到推送消息列表中
			self.push_msgs,self.messages = self.messages,self.push_msgs
			push(self)
		end
		--等待下一条消息
		self.sema:wait(60)
	end
end

--心跳协程
--self.on_message = function(self,data,type) end
--self.on_close = function(self,errmsg,code) end
local function heart_thread(self)
	while self.conn and not self.conn.fatal and not self.killed do
		local ok,err = self.conn:send_ping()
		self.sema_heart:wait(self.heart)
	end
end

--接收消息协程
local function receive_thread(self)
	local break_err = nil
	local close_code = 0
	local need_close = true
	
	local tmp_data_array = newtable(2,0)
	while not self.conn.fatal and not self.killed do
		local data, ty, err = self.conn:recv_frame()
		-- core.log.info('receive message -> ',data,',',ty,',',err)
		--出错后直接关闭
		if self.conn.fatal then
			break_err = 'fatal err = ' .. (err or 'unknown')
			close_code = 1001
			break
		end

		--根据类型进行处理
		if ty == "ping" then
			--ping pong消息
			self.conn:send_pong()
		elseif ty == "text" or ty == "binary" then
			if err == 'again' then
				tmp_data_array[#tmp_data_array+1] = data
			else
				if #tmp_data_array > 0 then
					tmp_data_array[#tmp_data_array+1] = data
					data = t_concat(tmp_data_array)
					cleartable(tmp_data_array)
				end
				self.on_message(self,data or "",ty)
			end
		elseif ty == "close" then
			if self.conn.close then
				--如果是客户端，关闭连接
				self.conn:close()
			else
				--如果是服务端，标记关闭(需要等待发送消息队列发送完队列中消息)
				if self:close(0, 'close') then
					need_close = false
				end
			end
			break_err = 'close code = ' .. (err or 'unknown')
			break
		elseif not ty then
			if str_find(err, ": timeout", 1, true) then
				-- core.log.info('receive message timeout.')
				if self:close(1000,'timeout') then
					need_close = false
				end
				break_err = 'timeout'
				close_code = 1000
			end
		end
	end

	self.killed = true

	if self.sema_heart then
		self.sema_heart:post(1)
	end
	if self.sema then
		self.sema:post(1)
	end

	--回调关闭
	if self.on_close and need_close then
		self.on_close(self,break_err,close_code)
	end
end

--启动心跳
function _M:active_heart(heart_interval)
	if not self.conn or self.conn.fatal then return false end
	self.heart = tonumber(heart_interval or 3)
	if self.heart and self.heart > 0 then
		self.sema_heart = semaphore:new()
		self.thread_heart = spawn(heart_thread,self)
	end
	return true
end

--停止，清除各个协程
local _stop = function(self)
	self.killed = true
	if self.thread_receive then
		kill(self.thread_receive)
		self.thread_receive = nil
	end
	if self.thread_push then
		kill(self.thread_push)
		self.thread_push = nil
	end
	if self.thread_heart then
		kill(self.thread_heart)
		self.thread_heart = nil
	end
end

--启动
local _start = function(self)
	if not self.conn then return false end
	
	_stop(self)
	
	self.killed = false
	if self.on_message then
		self.thread_receive = spawn(receive_thread,self)
	end
	self.thread_push = spawn(push_thread,self)
	
	if self.heart then self:active_heart(self.heart) end
end

function _M:set_headers(headers)
	self.opts = self.opts or {}
	self.opts.headers = {}
	for k,v in pairs(headers or {}) do
		self.opts.headers[#self.opts.headers + 1] = k .. ': ' .. v
	end
end

function _M:is_alive()
	if self.conn and not self.conn.fatal and not self.killed then
		return true
	else
		return false
	end
end

--重连，仅客户端可用
function _M:reconnect()
	if not self.host then return false,'this is a service' end

	if self.conn and not self.conn.fatal and not self.conn.closed then
		return true,'the connect is healthy'
	end
	
	self.connect_count = (self.connect_count or 0) + 1
	self.conn = Client:new{
		timeout = self.timeout or 0,
		max_payload_len = self.max_payload_len or 65535,
	}
	local ok,err = self.conn:connect(self.host,self.opts)
	if not ok then
		self.conn = nil
		return false,err
	end
	
	_start(self)
	
	return true
end

--启动
function _M:run(on_message,on_close,heart_interval)
	self.on_message = on_message
	self.on_close = on_close
	self.heart = heart_interval

	self.messages = newtable(1000,5)
	self.push_msgs = newtable(1000,5)
	self.messages.count = 0
	self.messages.idx = 1
	self.push_msgs.count = 0
	self.push_msgs.idx = 1

	if not self.conn then
		if self.host then 
			return self:reconnect() 
		else
			self.conn = Server:new{
				timeout = self.timeout or 0,
				max_payload_len = self.max_payload_len or 65535,
			}
		end
	end
	
	_start(self)
	
	return true
end

--发送消息
function _M:send(content,ty)
	if not self.conn or self.conn.fatal then return false end
	--最大允许阻塞self.max_message_size个消息
	if self.max_message_size and self.messages.count > self.max_message_size then
		errlog('message pool full')
		return false
	end
  if not self.messages then
    return false
  end
	self.messages.count = self.messages.count + 1
	self.messages[self.messages.count] = get_one_msg_obj(content,ty)
	self.sema:post(1)
	return true
end

--关闭
function _M:close(code,reason)
	if not self.conn or self.conn.fatal then return false end
	
	if code and code > 0 then
		self.close_code = code
		self.close_reason = reason
	end
	
	self:send({
		code = code or 1000,
		reason = reason,
	},"close")
	
	if not self.on_message and self.on_close then
		self.on_close(self,reason,code or 1000)
	end
end

return _M
