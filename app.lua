--[[
本文件修改后，需重启服务才能生效
--]]
local console = core.log.info

local _M = {}

local route_check = require("common.check_route")
--初始化,服务启动时调用
--可选
_M.init = function()
	-- local init_db = require("common.init_db")
	-- init_db.init()

	-- app.thread_report = core.thread.pool:new(1000, 10000)
	-- app.thread_report:run()
	--
	-- app.thread_statistics = core.thread.pool:new(1000, 10000)
	-- app.thread_statistics:run()
	--
	-- local collector = require("data.collector")
	-- collector.run()

	-- 定时脚本合集 [appname][func1,func2]
	-- app.cron_conf = {}

	-- 每个app的脚本使用的资源
	-- app.statics = {}

	-- 加载所有脚本
	-- local scripts = require("data.scripts")
	-- scripts.load()

	-- 应用的 appname-secret  用于检验是否启用该应用和鉴权
	-- app.application = {}
	-- local applications = require("data.application")
	-- applications.init()
	--
	-- route_check.init_chekers(app.application)

	console("app init done...")
end

--可选
--阶段处理,开启了重载后生效
--可选
---[==[
_M.phase = {}

_M.phase.preread = function() end

_M.phase.rewrite = function() end

local get_req_headers = ngx.req.get_headers
local get_checker = route_check.get

_M.phase.access = function()
	local checker = get_checker(ngx.var.api_path)
	if not checker then
		ngx.exit(403)
	end

	---@diagnostic disable-next-line: need-check-nil
	if not checker(get_req_headers()) then
		ngx.exit(403)
	end
end

_M.phase.header_filter = function() end

_M.phase.body_filter = function() end

_M.phase.log = function() end

--]==]

return _M
