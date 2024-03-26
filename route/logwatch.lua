--[[
服务连接
--]]
local Websocket_Server = core.websocket.server
local respond = core.respond
local spawn = ngx.thread.spawn
local loginfo = core.log.info

local on_message = function(client, data, opcode)
  loginfo("websocket message -> data = ", data)
  if data == 'close' then
    client:send("client---->close~")
    client:close(1000, "on_close killed")
  end
end

local on_close = function(client, data, code)
	client.closed = true
	loginfo("websocket closed -> code = ", code)
end

local check_worker_killed = function(client)
	if client then
		client:close(1000, "worker killed")
	end
end

local watch_log = function(appname, script_id, client)
	local k = "statistics:log-watch:" .. appname

	if script_id ~= "0" then
		k = k .. ":" .. script_id
	end

	---@diagnostic disable-next-line: undefined-field
	db.redis:subscribe(k, function(message)
		if client.killed or not client:send(message) then
			client:close(1000, "worker killed")
			return "exit"
		end
	end)
end

local _M = function(args, headers)
	--创建服务
	local service = Websocket_Server:new()
	if not service then
		return respond(-1, {}, "wrong connect mode")
	end

	--当worker关闭时，连接自动关闭
	spawn(check_worker_killed, service)

	-- spawn(watch_log, headers.appname, service)
	spawn(watch_log, args.appname, args.script_id, service)

	local heart = 3
	--服务启动
	service:run(on_message, on_close, heart)

	return respond(0, {}, "ok")
end

return _M
