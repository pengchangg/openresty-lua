--[[
zcenter.stream
--]]
local tostring = tostring
local type = type

local update_time = ngx.update_time
local ngx_now = ngx.now
local semaphore = require 'ngx.semaphore'
local sleep = ngx.sleep
local decode_base64 = ngx.decode_base64
local md5 = ngx.md5
local ngx_process = require "ngx.process" 

local sub = string.sub
local upper = string.upper

local go = core.go
local loginfo = core.log.info
local recinfo = core.log.record
local newtab = core.table.new
local deltab = core.table.release
local encode = core.cjson.encode
local decode = core.cjson.decode
local threadpool = core.thread.pool
local post = core.http.post
local split = core.string.split

local mesh = require 'zcenter.mesh'

local _M = {version = 0.1}

local uri = {
	producer = '/stream/producer',
	consumer = '/stream/consumer',
}

local consumers = {}
local producers = {}

_M.init = function()
end

_M.listen = function(server, topic, group, worker, on_message, on_close)
	if not topic then
		return false, 'no topic'
	end
	if not on_message then
		return false, 'no on_message'
	end
	
	if not group then
		group = 'config:' .. ngx_process.get_master_pid()
	end

	if not worker then
		worker = 'config:' .. ngx_process.get_master_pid() .. ':' .. ngx.worker.id()
	end

	if not consumers[topic] then
		consumers[topic] = {}
	end
	if not consumers[topic][group] then
		consumers[topic][group] = {}
	end
	if consumers[topic][group][worker] then
		return false,'arlready listen to topic -> ' .. topic .. ' in group -> ' .. group .. ' by worker -> ' .. worker
	end

	local ws,err = mesh.new_ws(uri.consumer,{
		topic = topic,
		group = group,
		server = server,
		worker = worker,
	},function(client,message,msgtype)
		on_message(client, message, msgtype)
	end,function(client,reason,code)
		consumers[topic][group][worker] = nil
		if on_close then
			on_close(client, reason, code)
		end
	end)

	if not ws then
		return false,err or 'listen failed'
	end

	consumers[topic][group][worker] = ws
	
	return ws
end

local init_producer = function(topic)
	if producers[topic] then
		return producers[topic]
	end

	producers[topic] = mesh.new_ws(uri.producer,{
		topic = topic,
		ws = 1,
	},function(client,message,msgtype)

	end,function()
		producers[topic] = nil
	end)

	return producers[topic]
end

_M.send = function(topic,message)
	local producer = init_producer(topic)
	if not producer then
		return false, 'init producer failed.'
	end
	return producer:send(encode({
		payload = message
	}))
end

return _M