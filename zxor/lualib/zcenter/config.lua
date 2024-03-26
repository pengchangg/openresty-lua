--[[
zcenter.config
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
local cleartab = core.table.clear
local encode = core.cjson.encode
local decode = core.cjson.decode
local threadpool = core.thread.pool
local post = core.http.post
local split = core.string.split

local mesh = require 'zcenter.mesh'
local stream = require 'zcenter.stream'

local _M = {version = 0.1}

local config_cache = {}

local uri = {
	set = '/config/set',
	get = '/config/get',
	del = '/config/del',
	uuid = '/config/uuid',
	env = '/config/env',
}

local update_config = function(mtype,key,data,uptime,isall)
	local cd = config_cache[key]
	if cd and cd.__uptime and cd.__uptime > uptime then
		return
	end

	if mtype == 'del' then
		config_cache[key] = nil
		return
	end

	if type(data) == 'string' then
		data = decode(data)
	end
	if type(data) ~= 'table' then
		return
	end

	if not cd then
		config_cache[key] = {}
		cd = config_cache[key]
	end
	for k,v in pairs(data) do
		cd[k] = v
	end
	cd.__uptime = uptime
	if isall then
		cd.__all = true
	end
end

local on_change = function()
	local sname = config.zcenter.name
	local topic = "event:" .. sname
	local group = 'config:' .. ngx_process.get_master_pid() .. ':' .. ngx.worker.id()

	local wsclient = nil
	local err = nil
	local sema = semaphore:new()
	while not wsclient and not worker.killed do
		wsclient,err = stream.listen("config", topic, group, 'config', 
			function(client, message, msgtype)
				--core.log.info(message)
				local msg = decode(message)
				if not msg or not msg.payload then
					return
				end
				
				local payload = msg.payload
				if type(payload) == 'string' then
					payload = decode(payload)
				end
				if not payload then
					return
				end

				update_config(payload.type,payload.key,payload.data,payload.uptime)
			end,
			function(client, reason ,code)
				recinfo('info',{msg = "listen config change event closed.", reason = reason,code = code, topic = topic, group = group})
				cleartab(config_cache)
				wsclient = nil
				if sema then
					sema:post(1)
				end
			end
		)

		if wsclient then
			recinfo('info',{msg = 'listen to topic success.', topic = topic, group = group})
			while wsclient and not worker.killed do
				if sema then
					sema:wait(60)
				else
					sleep(60)
				end
			end
		else
			recinfo('error',{msg = 'listen to topic failed.', topic = topic, group = group, err = err or 'unknown'})
		end

		sleep(0.5)
	end
end

_M.init = function()
	if not config.zcenter or not config.zcenter.gate or not config.zcenter.name then return false,'less server config' end
	if config.zcenter.not_need_config then
		return
	end
	go(0,on_change)
end

local request = function(url,args,body)
	local ok,body = mesh.post(url,args,body)

	if not ok then
		return false,body
	end

	local resp = decode(body)
	if not resp then
		return false, body
	end

	if resp.result ~= 0 then
		return false, resp.errmsg
	end

	return resp.data or true
end

_M.set = function(key,values)
	return request(uri.set,{key = key},values)
end

_M.get = function(key,fields)
	if config_cache[key] then
		if config_cache[key].__all then
			return config_cache[key]
		end

		local hasall = true
		if fields then
			for _,field in ipairs(fields) do
				if not config_cache[key][field] then
					hasall = false
					break
				end
			end
		else
			hasall = false
		end

		if hasall then
			return config_cache[key]
		end
	end

	local data, err = request(uri.get,{key = key,fields = fields})
	if not data then
		return false,err
	end

	update_config('set',key,data,ngx_now(),not fields)
	return data
end

_M.del = function(key,fields)
	return request(uri.del,{key = key,fields = fields})
end

_M.get_uuid = function(group,initvalue)
	return request(uri.uuid,{group = group,initvalue = initvalue})
end

_M.get_env = function ()
	local env,err = request(uri.env)
	if not env then
		return false,err
	end

	if type(env) ~= 'table' then
		return false,'wrong env data'
	end

	for k, v in pairs(env) do
		local nv = decode(v)
		if nv then
			env[k] = nv
		end
	end

	return env
end

return _M