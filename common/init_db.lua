local _M = {}

_M._VERSION = "0.0.1"

local ddl = function()
	local f, err = io.open("./statisctics.sql", "r")
	if not err and f ~= nil then
		local content = f:read("*a")
		f:close()
		-- core.log.info("statisctics.sql ===> content:", content)
		if content then
			---@diagnostic disable-next-line: undefined-field
			local ret, err = db.mysql:query(content)
			core.log.error("init_ddl sql error--->", core.cjson.encode(err), "--->ret:", core.cjson.encode(ret))
		end
		core.log.info("statisctics.sql ===> done:")
		return
	end

	core.log.error("read file error--->", err)
end

-- ddl 初始化
_M.init = function()
	if ngx.worker.id() == 0 then
		core.go(0, ddl)
	end
end

return _M
