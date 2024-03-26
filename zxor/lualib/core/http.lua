--[[
http功能接口
timeout -- 单位ms
--]]
local random = math.random
local type = type

local core_table = require 'core.table'
local newtab = core_table.new
local t_concat = core_table.concat
local http = require "resty.http.http"
local cjson = require "core.cjson"

local request = function(url,args,headers,body,verify,method,timeout)
	local httpc = http.new()
	if not httpc then
		return false,'new http client failed'
	end
	if timeout then
		httpc:set_timeout(timeout)
	end
	local rs,err = httpc:request_uri(url,{
		method = method or "GET",
		query = args,
		body = body,
		headers = headers,
		ssl_verify = verify or false,
	})
	
	if not rs then
		return false,err
	end
	
	if rs.status == 302 or rs.status == 301 then
		return core.http.get(rs.headers.Location,{})
	end
	
	if 200 ~= rs.status then
		return false,rs.body or '',rs.status
	end
		
	return true,rs.body,rs.headers
end

local _M = {}

_M.get = function(url,args,headers,verify,timeout)
	return request(url,args,headers,nil,verify,nil,timeout)
end

_M.post = function(url,args,body,headers,verify,timeout)
	if type(body) == 'table' then body = cjson.encode(body) end
	return request(url,args,headers,body,verify,'POST',timeout)
end

_M.head = function(url,args,headers,verify,timeout)
	return request(url,args,headers,nil,verify,'HEAD',timeout)
end

_M.put = function(url,args,body,headers,verify,timeout)
	return request(url,args,headers,body,verify,'PUT',timeout)
end

_M.delete = function(url,args,headers,verify,timeout)
	return request(url,args,headers,nil,verify,'DELETE',timeout)
end

_M.upload = function(url, args, files, headers, verify, timeout)
	if type(files) ~= 'table' then
		return false, 'no file data'
	end

	local boundary = '----FormBoundary' .. random(100000, 999999)
	headers = headers or newtab(2, 0)
	headers["Content-Type"] = "multipart/form-data;boundary=" .. boundary

	local num = 0
	local tb = newtab(#files * 11 + 3, 0)
	for idx, file in ipairs(files) do
		if  type(file.data) == 'string' then
			tb[#tb+1] = '--'
			tb[#tb+1] = boundary
			tb[#tb+1] = '\r\n'
			tb[#tb+1] = 'Content-Disposition: form-data; name="file"; filename="'
			tb[#tb+1] = file.name or ('file_' .. idx)
			tb[#tb+1] = '"\r\n'
			tb[#tb+1] = 'Content-Type: '
			tb[#tb+1] = file.type or 'application/octet-stream'
			tb[#tb+1] = '\r\n\r\n'
			tb[#tb+1] = file.data
			tb[#tb+1] = '\r\n'
			num = num + 1
		end
	end

	if num < 1 then
		return false, 'no file data'
	end

	tb[#tb+1] = '--'
	tb[#tb+1] = boundary
	tb[#tb+1] = '--\r\n'

	local body = t_concat(tb)
	headers["Content-Length"] = #body
	return request(url, args, headers, body, verify, "POST", timeout)
end

return _M