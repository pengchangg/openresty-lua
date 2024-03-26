--[[
zservice.mesh
--]]
local type = type

local update_time = ngx.update_time
local ngx_now = ngx.now
local sleep = ngx.sleep
local md5 = ngx.md5
local decode_base64 = ngx.decode_base64
local spawn = ngx.thread.spawn

local upper = string.upper
local sub = string.sub

local newtab = core.table.new
local deltab = core.table.release
local encode = core.cjson.encode
local decode = core.cjson.decode
local go = core.go
local loginfo = core.log.info
local recinfo = core.log.record
local post = core.http.post
local get = core.http.get
local split = core.string.split
local c_wsclient = core.websocket.client

local _M = {version = 0.1}

local mesh = {}

local uri = {
	get_token = '/account/v1/internal/service/get_token',
	heart =  '/register/heart',
	offline = '/register/logout',
}

local refresh_token = function()
	update_time()
	local reqargs = 'serverId=' .. mesh.conf.id .. '&serverName=' .. mesh.conf.name
	local ok,body,headers = post(uri.get_token ,nil,reqargs,{
		["Content-Type"] = 'application/x-www-form-urlencoded',
		time = ngx_now(),
		sign = upper(md5(reqargs .. '&token=' .. mesh.conf.key))
	},false,2000)

	if not ok then
		return false,body
	end

	local resp = decode(body)
	if not resp then
		return false,'wrong respond data'
	end

	if not resp.data or not resp.data.token then
		return false, resp.message
	end

	local tds = split(resp.data.token,'.')
	if #tds < 3 then
		return false, 'wrong token data'
	end
	
	local jwtobj = decode(decode_base64(tds[2]))
	if not jwtobj then
		return false, 'wrong token sign data'
	end

	mesh.token = {
		data = resp.data.token,
		expire = jwtobj.exp - 10,
	}

	loginfo(encode(mesh.token))

	return resp.data.token
end

local do_heart = function(offline)
	if not mesh.token or not mesh.token.data then return end

	local url = uri.heart
	if offline then
		url = uri.offline
	end
	local ok,body = post(url,nil,{
		host = mesh.conf.host,
		port = mesh.conf.port or config.http_ports[1],
		weight = mesh.conf.weight,
	},{
		authorization = mesh.token.data
	})
end

local keep_alive = function()
	while not worker.killed do
		if not mesh.token or not mesh.token.expire or mesh.token.expire < ngx_now() then
			if not mesh.thread_pool or not mesh.thread_pool:add(refresh_token) then
				refresh_token()
			end
		end

		if not mesh.thread_pool or not mesh.thread_pool:add(do_heart) then
			do_heart()
		end

		sleep(5)
	end

	do_heart(true)
end

_M.init = function()
	mesh.conf = config.zcenter
	if not mesh.conf.gate or not mesh.conf.id or not mesh.conf.key or not mesh.conf.name then return false,'less server config' end
	
	for k, v in pairs(uri) do
		uri[k] = mesh.conf.gate .. v
	end

	mesh.conf.gate_ws = 'ws' .. sub(mesh.conf.gate,5)

	refresh_token()
	if ngx.worker.id() == 0 then
		mesh.thread_pool = core.thread.pool:new(2, 1000)
		go(0, keep_alive)
	end
end

_M.get_token = function()
	if not mesh.token or not mesh.token.expire or mesh.token.expire < ngx_now() then
		local ok,err = refresh_token()
		if not ok then
			return nil,err
		end
	end

	return mesh.token.data
end

_M.get = function(uri,args,headers)
	local token = _M.get_token()
	if not token then
		return false, 'get token failed'
	end

	headers = headers or {}
	headers.authorization = 'Bearer ' .. token
	return get(mesh.conf.gate .. uri,args,headers)
end

_M.post = function(uri,args,body,headers)
	local token = _M.get_token()
	if not token then
		return false, 'get token failed'
	end

	headers = headers or {}
	headers.authorization = 'Bearer ' .. token
	return post(mesh.conf.gate .. uri,args,body,headers)
end

_M.new_ws = function(uri,args,on_message,on_close)
	local token = _M.get_token()
	if not token then
		return false, 'get token failed.'
	end
	local url = mesh.conf.gate_ws .. uri .. '?'
	for k,v in pairs(args) do
		url = url .. k .. '=' .. v .. '&'
	end
	url = url .. ngx.now()

	--loginfo('ws connect to ', url)
	local ws = c_wsclient:new(url)
	ws:set_headers({
		authorization = token
	})
	
	if on_message then
		go(0,function()
			local ok,err = ws:run(on_message,on_close,30)
			if not ok then
				if on_close then
					on_close(ws,'connect failed',-1)
				end
			end

			while not worker.killed and ws and ws:is_alive() do
				sleep(10)
			end
			
			if ws then
				ws:close()
			end
		end)
	end

	return ws
end

return _M