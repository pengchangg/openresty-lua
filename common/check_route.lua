local ipairs = ipairs

local ngx_time = ngx.time
local ngx_md5 = ngx.md5
local math_abs = math.abs
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local getfiles = core.shell.getfiles

local _M = {}

local applications = {}
local checker_route = {}
_M._VERSION = "0.0.1"

local checker_route_api = function(headers)
	if not headers.appname or not headers.sign or not headers.t then
		return false
	end

	if math_abs(headers.t - ngx_time()) > 5 then
		return false
	end

	return headers.sign == string_lower(ngx_md5(applications[headers.appname] .. headers.t))
end

local checker_route_admin = function(headers)
	if not headers.sign or not headers.t then
		return false
	end

	if math_abs(headers.t - ngx_time()) > 5 then
		return false
	end

	---@diagnostic disable-next-line: undefined-field
	return headers.sign == string_lower(ngx_md5(config.admin_key .. headers.t))
end

local checker_route_for_debug = function(headers)
	return true
end

local checker_route_for_ta = function(headers)
	local ta_appid = headers["ta-appid"] or false
	if ta_appid then
		return true
	end
	return false
end
function _M.init_chekers(apps)
	applications = apps

	---@diagnostic disable-next-line: undefined-field
	local indebug = (config.env == "dev")
	local files = getfiles("route/api", "lua")
	for _, file in ipairs(files) do
		---@diagnostic disable-next-line: undefined-field
		local p1, p2 = string_find(file, config.route_root)
		if p1 and p2 then
			checker_route[string_sub(file, p2 + 1)] = indebug and checker_route_for_debug or checker_route_api
		end
	end

	files = getfiles("route/admin", "lua")
	for _, file in ipairs(files) do
		---@diagnostic disable-next-line: undefined-field
		local p1, p2 = string_find(file, config.route_root)
		if p1 and p2 then
			checker_route[string_sub(file, p2 + 1)] = indebug and checker_route_for_debug or checker_route_admin
		end
	end

	files = getfiles("route", "lua")
	for _, file in ipairs(files) do
		---@diagnostic disable-next-line: undefined-field
		local p1, p2 = string_find(file, config.route_root)
		if p1 and p2 then
			checker_route[string_sub(file, p2 + 1)] = checker_route_for_debug
		end
	end
	files = getfiles("route/ta", "lua")
	for _, file in ipairs(files) do
		---@diagnostic disable-next-line: undefined-field
		local p1, p2 = string_find(file, config.route_root)
		if p1 and p2 then
			checker_route[string_sub(file, p2 + 1)] = checker_route_for_ta
		end
	end
end

function _M.get(api_path)
	return checker_route[api_path]
end

return _M
