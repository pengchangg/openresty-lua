local json = core.cjson
local loginfo = core.log.info

-- 获取当前时间
local function get_current_time()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- 发送事件
local function send_event(event, data)
	local id = "id: " .. ngx.now() .. "\n"
	local event_str = "event: " .. event .. "\n"
	local data_str = "data: " .. json.encode(data) .. "\n\n"
	return ngx.print(id .. event_str .. data_str)
end

local _M = function(args, headers)
	-- 设置 content type 为 text/event-stream
	ngx.header.content_type = "text/event-stream"
	ngx.header.cache_control = "no-cache"
	ngx.header["X-Accel-Buffering"] = "no"

	local function handle_client_close()
		-- 在这里执行连接关闭时的操作
		loginfo("=========Client closed the connection========")
	end

	-- 为当前请求注册连接关闭事件的处理函数
	ngx.on_abort(handle_client_close)

	-- 事件循环
	while true do
		local current_time = get_current_time()

		send_event("ping", { time = current_time })
		send_event("msg", "This is a message at time " .. current_time)

		ngx.flush(true)

		-- 休眠1秒后再次执行循环
		ngx.sleep(3)
	end
end

return _M
