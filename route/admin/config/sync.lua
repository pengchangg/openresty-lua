local respond = core.respond
local scripts = require("data.scripts")
local ddl = require("common.ddl")
local loginfo = core.log.info
local encode = core.cjosn.encode
local ngx_time = ngx.time
local string_lower = string.lower
local ngx_md5 = ngx.md5

---@diagnostic disable-next-line: undefined-field
local isOnline = (config.env == "online")

---@diagnostic disable-next-line: undefined-field
local online_url = config.online_url or false

---@diagnostic disable-next-line: undefined-field
local adminOnlineKey = config.admin_key_online or config.admin_key
local getSignHeaders = function()
	local headers = {}
	headers.t = ngx_time()
	headers.sign = string_lower(ngx_md5(adminOnlineKey .. headers.t))
	return headers
end

local _M = function(args, headers)
	local appname = args.appname
	if not appname then
		return respond(502, nil, "appname is empty", nil)
	end

	-- local server = args.to_server
	-- if not server then
	--     return respond(502, nil, 'server is empty', nil)
	-- end
	local scripts_list = args.scripts
	if not scripts_list or type(scripts_list) ~= "table" or #scripts_list < 1 then
		return respond(502, nil, "scripts is empty", nil)
	end

	local table_ddl = args.table_ddl
	if not table_ddl or type(table_ddl) ~= "table" or #table_ddl < 1 then
		return respond(502, nil, "table_ddl is empty", nil)
	end
	if isOnline then
		scripts.sync_script(appname, scripts_list)
		ddl.sync_create_table(table_ddl)
	else
		if online_url then
			local body = {}
			body.scripts_list = scripts_list
			body.table_ddl = table_ddl
			body.appname = appname
			local h = getSignHeaders()
			local ok, rs = core.http.post(online_url .. "/admin/config/sync", nil, body, {
				["Content-Type"] = "application/json",
			}, h)

			loginfo(
				" sync config request Config:",
				encode({
					online_url = online_url,
					body = body,
					headers = h,
				}),
				" resp:",
				encode({
					ok = ok,
					rs = rs,
				})
			)
		else
			loginfo(" sync config : online_url is empty")
		end
	end

	return respond(0, nil, "ok", nil)
end

return _M
