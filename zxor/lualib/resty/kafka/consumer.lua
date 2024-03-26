-- Copyright (C) xyruler
-- group todo ...

local response = require "resty.kafka.response"
local request = require "resty.kafka.request"
local broker = require "resty.kafka.broker"
local client = require "resty.kafka.client"
local Errors = require "resty.kafka.errors"
local apikeys = require "resty.kafka.apikeys"

local setmetatable = setmetatable
local timer_at = ngx.timer.at
local timer_every = ngx.timer.every
local is_exiting = ngx.worker.exiting
local ngx_sleep = ngx.sleep
local ngx_log = ngx.log
local thread_spawn = ngx.thread.spawn
local thread_wait = ngx.thread.wait
local thread_kill = ngx.thread.kill
local ERR = ngx.ERR
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG
local debug = ngx.config.debug
local crc32 = ngx.crc32_short
local pcall = pcall
local pairs = pairs
local ipairs = ipairs

local t_remove = table.remove

local spawn = ngx.thread.spawn

local strlen = string.len

local API_VERSION_V0 = 0
local API_VERSION_V1 = 1
local API_VERSION_V2 = 2

local API_VERSION_V4 = 4

local API_VERSION_V7 = 2

local ReplicalId = -1
local MaxWaitTime = 300

local new_tab = core.table.new

local function correlation_id(self)
	local id = (self.correlation_id + 1) % 1073741824 -- 2^30
	self.correlation_id = id

	return id
end

local function fetch_encode(self)
	local req = request:new(apikeys.Fetch,correlation_id(self), self.client_id, self.api_version)
	req:int32(-1)	--replica_id 
	req:int32(self.max_wait_time or 100)
	req:int32(self.min_bytes or 1024)
	req:int32(self.topic_num)
	for topic,partitions in pairs(self.topics) do
		req:string(topic)
		req:int32(#partitions)
		for _,partition in ipairs(partitions) do
			req:int32(partition.id)
			req:int64(partition.offset + 1)
			req:int32(self.max_bytes or 102400)
		end
	end

	return req
end

local function fetch_decode(self,resp)
	local api_version = resp.api_version
	if api_version >= API_VERSION_V1 then
		local throttletime = resp:int32()
	elseif api_version >= API_VERSION_V7 then
		local errorcode = resp:int16()
		local sessionid = resp:int32()
	end
	
	local topic_num = resp:int32()
	local ret = new_tab(0, topic_num)
	for i = 1, topic_num do
		local topic = resp:string()
		local partition_num = resp:int32()
		--core.log.info('topic = ', topic, 'partition = ', partition_num)
		if #topic == 0 then break end
		ret[topic] = new_tab(0, partition_num)
		for j = 1, partition_num do
			local partition = resp:int32()
			ret[topic][partition] = {
				errcode = resp:int16(),
				maxoffset = resp:int64(),
				data = resp:message_set(topic,partition),
			}
	   end
	end
    
	return ret
end

local function offset_encode(self,time)
	time = time or (0LL - 1)
	local req = request:new(apikeys.ListOffsets,correlation_id(self), self.client_id, self.api_version)
	req:int32(-1)
	req:int32(self.topic_num)
	for topic,partitions in pairs(self.topics) do
		req:string(topic)
		req:int32(#partitions)
		for _,partition in pairs(partitions) do
			req:int32(partition.id)
			req:int64(time)
			if self.api_version == API_VERSION_V0 then
				req:int32(0)
			end
		end
	end

	return req
end

local function offset_decode(self,resp)
	local api_version = resp.api_version

	local topic_num = resp:int32()
	local ret = new_tab(0, topic_num)
	
	for i = 1, topic_num do
		local topic = resp:string()
		local partition_num = resp:int32()
		ret[topic] = {}

		for j = 1, partition_num do
			local partition = resp:int32()
			ret[topic][partition] = {
				errcode = resp:int16(),
			}
			if api_version == API_VERSION_V1 then
			   ret[topic][partition].timestamp = resp:int64()
			end

			if api_version == API_VERSION_V0 then
				local offset_num = resp:int32()
				ret[topic][partition].offsets = {}
				for k = 1,offset_num do
					ret[topic][partition].offsets[k] = resp:int64()
				end
			else
				ret[topic][partition].offset = resp:int64()
			end

		end
	end

	--core.log.info('ret -- ',core.cjson.encode(ret))
	return ret
end

local function group_coordinator_encode(self)
	local req = request:new(apikeys.Offset,correlation_id(self), self.client_id, self.api_version)
	req:string(self.group)

	return req
end

local function group_coordinator_decode(self,resp)
	local api_version = resp.api_version

	local ret = {
		errcode = resp:int16(),
		coordinatorHost = resp:string(),
		coordinatorPort = resp:int32(),
	}

	return ret
end

local function offset_commit_encode(self,one)
	local req = request:new(apikeys.OffsetCommit,correlation_id(self), self.client_id, self.api_version)
	req:string(self.group)
	if self.api_version == API_VERSION_V1 or self.api_version == API_VERSION_V2 then
		req:int32(-1)
		req:string(self.client_id)
		if self.api_version == API_VERSION_V2 then
			req:int64(0)
		end
	end

	if one then
		req:int32(1)
		req:string(one.topic)
		req:int32(1)
		req:int32(one.partition)
		req:int64(one.offset)
		if self.api_version == API_VERSION_V1 then
			req:int64(0)
		end
		req:string(one.metadata or "")
	else
		req:int32(self.topic_num)
		for topic,partitions in pairs(self.topics) do
			req:string(topic)
			req:int32(#partitions)
			for _,partition in pairs(partitions) do
				req:int32(partition.id)
				req:int64(partition.offset)
				if self.api_version == API_VERSION_V1 then
					req:int64(0)
				end
				req:string(partition.metadata or "")
			end
		end
	end


	return req
end

local function offset_commint_decode(self,resp)
	local api_version = resp.api_version

	local topic_num = resp:int32()
	local ret = new_tab(0, topic_num)
	
	for i = 1, topic_num do
		local topic = resp:string()
		local partition_num = resp:int32()
		ret[topic] = {}
		for j = 1, partition_num do
			local partition = resp:int32()
			ret[topic][partition] = {
				errcode = resp:int16(),
			}
		end
	end

	--core.log.info(core.cjson.encode(ret))
	return ret
end

local function offset_fetch_encode(self)
	local req = request:new(apikeys.OffsetFetch,correlation_id(self), self.client_id, self.api_version)
	req:string(self.group)
	req:int32(self.topic_num)
	for topic,partitions in pairs(self.topics) do
		req:string(topic)
		req:int32(#partitions)
		for _,partition in ipairs(partitions) do
			req:int32(partition.id)
		end
	end
	
	return req
end

local function offset_fetch_decode(self,resp)
	local api_version = resp.api_version

	local topic_num = resp:int32()
	local ret = new_tab(0, topic_num)

	for i = 1, topic_num do
		local topic = resp:string()
		local partition_num = resp:int32()
		ret[topic] = {}
		for j = 1, partition_num do
			local partition = resp:int32()
			ret[topic][partition] = {
				offset = resp:int64(),
				metadata = resp:string(),
				errcode = resp:int16(),
			}

			--core.log.info('{"',topic,'":{"',partition,'":"offset":',tonumber(ret[topic][partition].offset),',"errcode":',ret[topic][partition].errcode, '}}')
		end
	end

	return ret
end

local function commit_offset(self,one)
	local resp,err = self.broker:send_receive(offset_commit_encode(self,one))
	if not resp then
		ngx_log(INFO, "broker fetch offset failed, err:", err)
		return false
	end

	return offset_commint_decode(self,resp)
end

local function update_offset(self)
	local resp,err = self.broker:send_receive(offset_fetch_encode(self))
	if not resp then
		ngx_log(INFO, "broker fetch offset failed, err:", err)
		return false
	end

	local ret = offset_fetch_decode(self,resp)
	for topic,partitions in pairs(ret) do
		self.topics[topic] = {}
		for partition,data in pairs(partitions) do
			self.topics[topic][#self.topics[topic] + 1] = {
				id = partition,
				offset = data.offset,
				metadata = data.metadata,
			}
		end
	end

	return true
end

local function _update_partion_offset(self,topic,partid,offset)
	--更新偏移值
	for _,v in ipairs(self.topics[topic] or {}) do
		if v.id == partid and v.offset < offset then
			v.offset = offset
		end
	end
end

local function commit_offset_when_fetch_error_1(self,topic,partition)
	local resp,err = self.broker:send_receive(offset_encode(self))
	if not resp then return false end
	
	local ret = offset_decode(self,resp)
	if not ret[topic] or not ret[topic][partition] then return false end

	if commit_offset(self,{
		topic = topic,
		partition = partition,
		offset = ret[topic][partition].offset - 1,
	}) then
		_update_partion_offset(self,topic,partition, ret[topic][partition].offset - 1)
	end
end

local function request_data(self)
	local resp, err = self.broker:send_receive(fetch_encode(self))
	if not resp then
		ngx_log(INFO, "broker fetch message failed, err:", err)
		ngx_sleep(1)
		return nil
	end

	local messages = new_tab(1000,0)
	local idx = 0
	local data = fetch_decode(self,resp)
	for topic,partitions in pairs(data) do
		for partid,partition in pairs(partitions) do
			if partition.errcode == 0 then
				for _,v in ipairs(partition.data) do
					idx = idx + 1
					messages[idx] = v
				end
			elseif partition.errcode == 1 then
				core.log.info('fetch topic = ',topic,' partition = ',partition.id or 0, ' error = ',partition.errcode)
				commit_offset_when_fetch_error_1(self,topic,partid)
			end
		end
	end

	return messages
end

local consumer = {_VERSION = "0.01"}

consumer.new = function(self,broker,topics,on_consume,group,client_id,opts)
	opts = opts or {}
	local c = setmetatable({
		client_id = client_id,
		group = group,
		broker = broker,
		on_consume = on_consume,
		correlation_id = 1,
		topics = topics,
		messages = {},
		message_consumer_idx = 0,
		topic_num = 0,
		api_version = opts.api_version or API_VERSION_V1,
		max_wait_time = opts.max_wait_time or 2000,
		min_bytes = opts.min_bytes or 1,
		max_bytes = opts.max_bytes or 102400,
	}, { __index = consumer })

	for _,_ in pairs(topics) do
		c.topic_num = c.topic_num + 1
	end
	
	return c
end

function consumer.pull(self)
	if not self.messages or #self.messages < 1 then
		self.messages = request_data(self)
		if not self.messages or #self.messages < 1 then
			return nil
		end
	end

	self.message_consumer_idx = self.message_consumer_idx + 1
	local message = self.messages[self.message_consumer_idx]

	if self.message_consumer_idx == #self.messages then
		self.messages = nil
		self.message_consumer_idx = 0
	end

	return message
end

function consumer.run(self)
	if not self.on_consume then return false,'no consume function.' end
	if not self.broker then return false,'no broker' end
	if not update_offset(self) then return false,'init offset failed.' end

	self.thread_update_offset = thread_spawn(function()
		while not self.killed and not worker.killed do 
			ngx_sleep(1)
			commit_offset(self)
		end
	end)

	self.thread_pull = thread_spawn(function()
		while not self.killed and not worker.killed do
			local message = self:pull()
			if not self.killed and not worker.killed and message then
				_update_partion_offset(self,message.topic,message.partition,message.offset)
				self.on_consume(message.topic,message.key,message.value)
			end
		end
	end)

	return true
end

function consumer.stop(self)
	self.killed = true
	if self.thread_pull then
		thread_wait(self.thread_pull)
	end
	if self.thread_update_offset then
		thread_wait(self.thread_update_offset)
	end
end

local manager = {_VERSION = "0.01"}

function manager.new(self, broker_list, topics, group, opts,on_consume)
	local cs = setmetatable({
		client = client:new(broker_list,opts),
		topics = topics,
		brokers = {},
		consumers = {},
		opts = opts,
		group = group,
		on_consume = on_consume,
	}, { __index = manager })
	
	return cs
end

local _init_partitions = function(self, topic)
	local brokers, partitions = self.client:fetch_metadata(topic)
	if not brokers then return false,'no brokers data' end
	if not partitions then return false,'no partitions data' end

	--core.log.info(core.cjson.encode(brokers))
	--core.log.info(core.cjson.encode(partitions))

	for bid,v in pairs(brokers) do
		if not self.brokers[bid] then
			self.brokers[bid] = {}
			self.brokers[bid].broker = broker:new(v.host, v.port, self.client.socket_config)
			self.brokers[bid].topics = {}
		end
	end

	for i = 0 ,partitions.num - 1 do
		if partitions[i] then
			if not self.brokers[partitions[i].leader] then return false,'wrong broker info' end
			self.brokers[partitions[i].leader].topics[topic] = self.brokers[partitions[i].leader].topics[topic] or {}
			local topics = self.brokers[partitions[i].leader].topics

			topics[topic][#topics[topic] + 1] = {
				id = partitions[i].id,
				offset = 0LL - 2,
				maxoffset = -1,
			}
		end
	end

	return true
end

local _init_brokers = function(self)
	self.brokers = {}
	for _,topic in ipairs(self.topics) do
		if not _init_partitions(self,topic) then
			ngx_sleep(1)
			if not _init_partitions(self,topic) then
				return nil,'init consumer failed.' 
			end
		end
	end

	return true
end

local _init_consumers = function(self,delay_run)
	self.consumers = {}
	for bid,v in pairs(self.brokers) do
		self.consumers[bid] = consumer:new(v.broker,v.topics,self.on_consume,self.group,self.client.client_id .. '_' .. bid,self.opts)
	end

	if delay_run then return true end

	for _,consumer in pairs(self.consumers) do
		local ok,err = consumer:run()
		if not ok then 
			self:stop()
			return false,'start consumer failed. -> ' .. err
		end
	end

	return true
end

local _check_metadata = function(self)
	local brokers = self.brokers
	local bchange = true

	local ok,err = _init_brokers(self)
	if not ok then
		self.brokers = brokers
		return false
	end

	for bid,v in pairs(brokers) do
		bchange = false
		local nb = self.brokers[bid]
		if not nb then
			bchange = true
			break
		end

		if v.broker.host ~=  nb.broker.host or v.broker.port ~= nb.broker.port then
			bchange = true
			break
		end

		for topic,partitions in pairs(v.topics) do
			if not nb.topics[topic] then
				bchange = true
				break
			end

			for _,partition in ipairs(partitions) do
				local bfind = false

				for _,np in ipairs(nb.topics[topic]) do
					if np.id == partition.id then
						bfind = true
						break
					end
				end

				if not bfind then
					bchange = true
					break
				end
			end
		end
	end

	return bchange
end

function manager.run(self)
	if not self.on_consume then return false,'no consume function.' end
	if not self.topics then return false,'no topics' end
	if not self.client then return false,'no client' end

	if self.running then return false,'consumer is running.' end

	self.killed = nil

	self.thread_check_metadata = thread_spawn(function()
		while not self.killed and not worker.killed do
			if _check_metadata(self) then
				for _,consumer in pairs(self.consumers) do
					consumer:stop()
				end
				_init_consumers(self)
			end

			ngx_sleep(1)
		end
	end)

	self.running = true
end

function manager.stop(self)
	if not self.running then return true end

	for _,consumer in pairs(self.consumers) do
		consumer:stop()
	end

	self.killed = true

	thread_wait(self.thread_check_metadata)

	self.running = nil
	
	return true
end

return manager
