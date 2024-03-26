local get_method = ngx.req.get_method

local app = app or {}
if not app.phase then app.phase = {} end
local rewrite = app.phase.rewrite

local cors = (config and config.cors or {}) or {}

local _M = function()
    if cors.allow then
        if get_method() == 'OPTIONS' then
            ngx.exit(200)
        end
    end

    if rewrite then
	    rewrite()
    end
end

return _M