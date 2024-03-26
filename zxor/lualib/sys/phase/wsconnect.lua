--[[
服务连接
--]]
local Websocket_Server = core.websocket.server
local respond = core.respond
local console = core.log.info
local cjson = core.cjson
local route = route
local type = type
local sleep = ngx.sleep
local spawn = ngx.thread.spawn
local release_table = core.table.release
local recreq = config.debug or config.record_request_info
local ngx_updatetime = ngx.update_time
local ngx_now = ngx.now
local status = config.status
local logrec = core.log.record
local newtable = core.table.new
local deltable = core.table.release
local encode = cjson.encode
local decode = cjson.decode

local host = "http://localhost"
if config.http_ports and config.http_ports[1] then
	host = host .. ":" .. config.http_ports[1]
end
local post = core.http.post
local auto_balance = config.use_websocket_autobalance

if not status then 
	status = {
		OK = 0,
		FAILED = -1,
		PRESTOP	= 99,
		SIGNERR = 100,
		URLERR = 101,
		ARGSERR = 102,
	}
end

local _rec_request_log = function(api,args,rs,cost,pcost,btime,etime)
	local loginfo = newtable(0,7,'core.request.loginfo')
	loginfo.api = api
	loginfo.args = args
	loginfo.rs = rs
	loginfo.cost = cost
	loginfo.pcost = pcost
	loginfo.btime = btime
	loginfo.etime = etime
	logrec('request',loginfo)
	deltable(loginfo)
end

local _do_request = function(client,msg,__time)
	local cost = nil
	local btime = __time
	if recreq then
		ngx_updatetime()
		cost = ngx_now() * 1000
		__time = cost - (__time * 1000)
	end
	msg = decode(msg)
	if msg and not msg.extra and type(msg.data) == 'table' then
		msg.extra = msg.data.extra
		msg.data.extra = nil
	end
	
	local ok,rs

	if not msg or not msg.url or not msg.data then
		rs = respond(status.ARGSERR,nil,'wrong args',msg and msg.extra)
	else
		local api = route.get(msg.url)
		if not api then
			rs = respond(status.URLERR,nil,'wrong url',msg.extra)
		else
			if auto_balance then
				msg.data.extra = msg.extra
				ok, rs = post(host .. msg.url, nil, msg.data, client.headers)
				if not ok then
					rs = respond(status.FAILED,nil,'call api failed',msg.extra)
				end
			else
				ok, rs = pcall(api, msg.data, client.headers)
				if not ok then
					logrec('error',{msg = 'call api failed.',err = rs, api = msg.url, args = msg.data})
					if config.debug then
						rs = respond(status.FAILED,nil,rs,msg.extra)
					else
						rs = respond(status.FAILED,nil,'call api failed',msg.extra)
					end
				end
			end
		end
	end

	local ret
	local ty = type(rs)
	if ty == "string" or ty =="number" then
		ret = rs
	elseif ty == 'table' then
		rs.extra = rs.extra or msg.extra
		
		local bdel = false
		if rs.__make_by_respond then
			bdel = true
			rs.__make_by_respond = nil
		end	
		
		ret = encode(rs)
		
		if bdel then
			release_table(rs)
		end
	else
		ret = encode(rs)
	end
	
	client:send(ret)
	if recreq then
		ngx_updatetime()
		local etime = ngx_now()
		cost = (etime * 1000)  - cost
		_rec_request_log(msg.url,msg.data,ret,cost + (__time or 0), cost, btime, etime)
	end
end

local on_message = function(client,msg)
	if not client then return false,'no client' end
	ngx_updatetime()
	local cur = ngx_now()
	if not app.pool_for_ws_request or not app.pool_for_ws_request:add(_do_request,client,msg,cur) then 
		_do_request(client,msg,cur)
	end
	
    return true
end

local on_close = function(client,data,code)
	if app.stream and app.stream.on_close then
		app.stream.on_close(client,data,code)
	end
	client.closed = true
	core.log.info('websocket closed -> code = ',code)
end

local check_worker_killed = function(client)
	while not worker.killed and not client.closed do
		sleep(60)
	end
	
	client:send(encode(respond(status.PRESTOP or 99,nil,'the service will stop in 10s.',nil)))	
	sleep(10)
	
	if client then
		client:close(1000,'worker killed')
	end
end

local _M = function(args, headers)
	--创建服务
	local service = Websocket_Server:new()
	if not service then return respond(-1,{},'wrong connect mode') end

	service.headers = headers or ngx.req.get_headers()
	service.headers["x-internal"] = "internal"
	--当worker关闭时，连接自动关闭
	spawn(check_worker_killed,service)

	if app.stream and app.stream.on_connect then
		app.stream.on_connect(service)
	end

	local onmsg = on_message
	local onclose = on_close
	local heart = 3
	if app.stream then
		if app.stream.on_message then
			onmsg = app.stream.on_message
		end
		if app.stream.on_close then
			onclose = app.stream.on_close
		end
		if app.stream.heart then
			heart = app.stream.heart.interval or 3
		end
	end

	--服务启动
	service:run(onmsg,onclose,heart)
	
	return respond(0,{},'ok')
end

return _M