--[[
路由管理
仅支持全匹配模式
--]]
local api_root = config.route_root or 'api'
local config = config
local route = {}
local s_lower = string.lower
local s_gsub = string.gsub

local in_debug = config and config.debug or false
local loginfo = core.log.info
local logerror = core.log.error

local _M = {}

local default_api = 'no route'

--获取路由
_M.get = function(path)
	path = s_lower(path)
	if not route[path] then
		local apipath = s_gsub(api_root .. path,'/','.')
		local api, err = core.loadscript(apipath, 'function')
		if not api then
			if in_debug then
				loginfo('require api function err -> apipath = ',apipath,' err ->',err or 'unkonwn')
			end
			api = default_api
		end

		if in_debug then
			return api
		end

		route[path] = api
	end

	if route[path] == 'no route' then
		return nil
	end

	return route[path]
end

--设置路由
_M.set = function(path,api)
	if not path or not api then
		return false
	end
	
	if type(api) == 'string' then
		local ok, fun = pcall(require, api)
		if ok then
			api = fun
		else
			logerror(fun)
		end
	end
	
	if type(api) ~= 'function' then
		logerror('get api function error-> path = ',path)
		return false
	end
	
	path = s_lower(path)
	route[path] = api
	
	return true
end

--设置默认的路由
_M.set_default = function(default)
	if type(default) == 'string' then
		local ok, fun = pcall(require, default)
		if ok then
			default = fun
		else
			logerror('set default route api error -> ' ,fun or 'unkonwn error')
		end
	end
	
	if type(default) == 'function' then
		default_api = default
	end
end

_M.get_routes = function()
	local rs = {}
	for r,_ in pairs(route) do
		rs[#rs + 1] = r
	end
	return rs
end

return _M