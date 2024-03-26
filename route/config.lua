local respond = core.respond
local decode = core.cjson.decode
local ngx_req_get_method = ngx.req.get_method
local http = require("core.http")
local add_header = require("ngx.resp").add_header

local _M = function(args, headers)
	-- if ngx_req_get_method() == "OPTIONS" then
	-- 	return respond(0, nil, "OK", nil)
	-- end
	local _, body, _ = http.get("https://g2020-shushu.laiyouxi.com/config", args, headers)

	return respond(0, decode(body or {}), "OK", nil)
end

return _M
