--[[
http模式下的content_by_lua
--]]
local cjson = core.cjson
local respond = core.respond
local logrec = core.log.record
local config = config
local route = route
local cjson_encode = cjson.encode
local cjson_decode = cjson.decode
local tonumber = tonumber
local tostring = tostring

local ngx_updatetime = ngx.update_time
local ngx_now = ngx.now
local ngx_req_start_time = ngx.req.start_time
local ngx_req_get_method = ngx.req.get_method
local ngx_req_read_body = ngx.req.read_body
local ngx_req_get_body_data = ngx.req.get_body_data
local ngx_req_get_uri_args = ngx.req.get_uri_args
local ngx_req_get_headers = ngx.req.get_headers
local ngx_say = ngx.say
local ngx_exit = ngx.exit

local strsub = string.sub

local record_request_info = config and (config.debug or config.record_request_info) or false
local status = config and config.status or nil
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

local no_need_read_post = config and config.no_need_read_post or false

local new_table = core.table.new
local release_table = core.table.release

local get_route = nil
if route then
	get_route = route.get
else
	get_route = function (api)
		return nil
	end
end

local _rec_request_log = function(api,args,rs,cost,btime,etime)
	local loginfo = new_table(0,7,'core.request.loginfo')
	loginfo.api = api
	loginfo.args = args
	loginfo.rs = rs
	loginfo.cost = cost
	loginfo.btime = btime
	loginfo.etime = etime
	logrec('request',loginfo)
	release_table(loginfo)
end

local route_prefix = config and (config.route_prefix or '') or ''
local route_prefix_len = #route_prefix

local get_args = function (api_path,args)
	--如果是post方法，获取post参数
	if ngx_req_get_method() == "POST" then
		if not no_need_read_post or not no_need_read_post[api_path] then
			ngx_req_read_body()
			local body_str = ngx_req_get_body_data()
			local args_post = nil
			if type(body_str) == 'string' then
				args_post = cjson_decode(body_str)
			end
			
			if not args_post then
				args_post = ngx.req.get_post_args()
			end
			
			if args_post then
				for k, v in pairs(args_post) do
					args[k] = v
				end
			end
		end
	end

	return args
end

local find_route = function (api_path,args)
	--整理参数
	api_path = api_path or ngx.var.api_path or ngx.var.uri
	args = args or ngx_req_get_uri_args() or {}
	if #api_path <= route_prefix_len then
		return nil, respond(status.URLERR, nil, '404 Not Found', args.extra), api_path
	end

	--去掉前缀
	if route_prefix_len > 1 then
		api_path = strsub(api_path,route_prefix_len + 1)
	end
	--如果无路由，返回默认结果
	if #api_path <= 1 then
		return nil, respond(status.OK, nil, 'Welcome to US', args.extra), api_path
	end

	--获取路由
	local api = get_route(api_path)
	if not api then
		return nil, respond(status.URLERR, nil, '404 Not Found', args.extra), api_path
	end
	
	return api, get_args(api_path, args), api_path
end

local make_respond = function (rs, api_path, args, brec)
	local ty = type(rs)
	if ty == "table" then
		rs.extra = rs.extra or (args and args.extra)
		local tmp = rs
		local bdel = false
		if tmp.__make_by_respond then
			tmp.__make_by_respond = nil
			bdel = true
		end
		rs = cjson_encode(tmp)
		if bdel then
			release_table(tmp)
		end
	else
		if rs then rs = tostring(rs) end
	end

	if brec then
		ngx_updatetime()
		local btime = ngx_req_start_time()
		local etime = ngx_now()
		local cost = etime * 1000 - btime * 1000
		_rec_request_log(api_path,args,rs,cost,btime,etime)
	end

	return rs
end

local _M = function(api_path,args)
	local api, all_args, rpath = find_route(api_path, args)
	if not api then
		return make_respond(all_args, api_path or rpath, args, false)
	end

	local ok, rs = pcall(api, all_args, ngx_req_get_headers())
	if not ok then
		logrec('error',{msg = 'call api failed.',err = rs, api = api_path or rpath, args = all_args})
		rs = respond(status.FAILED, nil, 'call api failed', all_args.extra)
	end

    return make_respond(rs, api_path or rpath, all_args, record_request_info)
end

return _M