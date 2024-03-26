local get_method = ngx.req.get_method
local get_headers = ngx.req.get_headers
local add_header = require("ngx.resp").add_header

local app = app or {}
if not app.phase then
	app.phase = {}
end
local header_filter = app.phase.header_filter

local cors = (config and config.cors or {}) or {}

local _M = function()
	if cors.allow then
		add_header("Access-Control-Allow-Origin", cors.origins or "*")
		if cors.origins and cors.origins ~= "*" then
			add_header("Vary", "Origin")
		end

		add_header(
			"Access-Control-Allow-Methods",
			cors.methods or "GET,POST,PUT,DELETE,PATCH,HEAD,OPTIONS,CONNECT,TRACE"
		)
		add_header("Access-Control-Max-Age", cors.age or "3600")
		add_header("Access-Control-Allow-Credentials", cors.credentials and "true" or "false")

		if cors.headers == "**" then
			local headers = get_headers() or {}
			add_header("Access-Control-Allow-Headers", headers["access-control-request-headers"] or "*")
		else
			add_header("Access-Control-Allow-Headers", cors.headers or "*")
		end

		if cors.expose_headers then
			add_header("Access-Control-Expose-Headers", cors.expose_headers)
		end
	end

	if header_filter then
		header_filter()
	end
end

return _M
