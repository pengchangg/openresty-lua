--[[
kafka
--]]
local config = require 'config'
local kafka_producer = require 'resty.kafka.producer'
local kafka_consumer = require 'resty.kafka.consumer'

local log_err = core.log.error

local _M = {}

for name,opts in pairs(config.kafka or {}) do
	if not opts.broker_list then
		log_err('Kafka config has wrong parameters. name = ',name)
	else
		if opts.type == 'producer' then
			_M[name] = kafka_producer:new(opts.broker_list,opts.config,opts.cluster_name)
			_M[name].type = 'producer'
		elseif opts.type == 'consumer' then
			if not opts.group or not opts.topic_list or not opts.dofun then 
				log_err('Kafka Consumer has wrong parameters. name = ',name)
			else
				local ok, fun = pcall(require, opts.dofun)
				if ok and type(fun) == 'function' then
					_M[name] = kafka_consumer:new(opts.broker_list,opts.topic_list,opts.group,opts.config,fun)
					_M[name].type = 'consumer'
				else
					log_err('Kafka Consumer dofun is not a function. name = ',name)
				end
			end
		end
	end
end

return _M