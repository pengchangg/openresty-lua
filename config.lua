--[[
本文件修改后，需重启服务才能生效
本模块中，不能直接执行require语句
--]]

local _M = {}
_M.debug = false --调试状态，生产时请设置为false

_M.env = sys.env.DEPLOY_ENV or "test"

---[[环境变量
-- _M.sys_env_list = {
-- 	"PROJECT_NAME",
-- 	"PROJECT_VERSION",
-- 	"DEPLOY_ENV",
-- 	"HOST_IP",
-- 	"LISTEN_PORT",
-- 	"EXPOSE_PORT",
-- 	"MYSQL_MASTER_HOST",
-- 	"MYSQL_MASTER_PORT",
-- 	"MYSQL_MASTER_USERNAME",
-- 	"MYSQL_MASTER_PASSWORD",
-- 	"MYSQL_SLAVE_HOST",
-- 	"MYSQL_SLAVE_PORT",
-- 	"MYSQL_SLAVE_USERNAME",
-- 	"MYSQL_SLAVE_PASSWORD",
-- 	"REDIS_HOST",
-- 	"REDIS_PORT",
-- 	"REDIS_PASSWORD",
-- 	"APIGATEHOST",
-- 	"APIGATEPORT",
-- 	"APIGATE_ID",
-- 	"APIGATE_NAME",
-- 	"APIGATE_SECRET",
-- }
--]]
-------------------------
--服务配置
--是否为单一进程服务
_M.singleton_work = false
--_M.worker_num = sys.env.WORKER_NUM or 'auto'
--服务使用的协议
--_M.use_tcp = true
--_M.use_udp = true
_M.use_http = true
_M.use_websocket = true
--_M.use_websocket_autobalance = true
--端口设置
--_M.tcp_ports = {sys.env.LISTEN_PORT or 8080}
--_M.udp_ports = {sys.env.LISTEN_PORT or 8081}
_M.http_ports = { sys.env.LISTEN_PORT or 8082 }

--最大的计时器数量
_M.max_running_timers = 25600
_M.lua_max_pending_timers = 102400

_M.record_request_info = false

_M.status = {
	OK = 0,
	FAILED = -1,
	SIGNERR = 100,
	URLERR = 101,
	ARGSERR = 102,
}

---------------------------
---[=[phase开关
--是否重载相应的处理过程，重载方法在app.lua中定义
_M.phase = {}
_M.phase.preread = false
_M.phase.rewrite = false
_M.phase.access = true
_M.phase.header_filter = false
_M.phase.body_filter = false
_M.phase.log = false
--]=]

---------------------------
--路由配置
--根目录设置
_M.route_root = "route" --默认为'api'
_M.route_prefix = "" --路由前缀

_M.admin_key = "!!uCHg7bJPyt9F" -- 后台鉴权key
_M.admin_key_online = "a4ieginpofyz9e"
-- TODO: 需要换成线上部署的url
_M.online_url = "https://xxx.laiyouxi.com"

--[[跨域设置
_M.cors = {
	allow = true,
	origins = "*",
	methods = "GET,POST,PUT,DELETE,PATCH,HEAD,OPTIONS,CONNECT,TRACE",
	age = 3600,
	credentials = false,
	headers = "*",
	--expose_headers = "",
}
--]]

--  设置http头信息
_M.http_add_headers = {
	"'Access-Control-Allow-Origin' '*'",
	"'Access-Control-Allow-Methods' 'GET, POST, OPTIONS'",
	"'Access-Control-Allow-Headers' 'Content-Type,XFILENAME,XFILECATEGORY,XFILESIZE,TA-Integration-Count,TA-Integration-Extra,TA-Integration-Type,TA-Integration-Version'",
}

_M.thread_pools = {
	worker = {
		threads = 8,
		max_queue = 32,
	},
}

----------------------------
---[=[缓存配置
_M.caches = {
	user = {
		share_dict_size = "1000m",
		lru_size = 50000,
		ttl = 0,
		neg_ttl = 60,
		get_from_db = "data.user.get",
		save_to_db = "data.user.update",
		--ipc_redis = 'userinfo_cache_ipc',
	},
}
--]=]

----------------------------
---[=[DB配置
_M.db = {}
--Mysql配置
_M.db.mysql = {
	type = "mysql",
	host = sys.env.MYSQL_MASTER_HOST or "192.168.50.205",
	port = sys.env.MYSQL_MASTER_PORT or 3306,
	user = sys.env.MYSQL_MASTER_USERNAME or "root",
	password = sys.env.MYSQL_MASTER_PASSWORD or "123123456",
	database = "zx_dataanalysis_statistics",
	concurrency = 4, --最大读写并发数,默认100
}

----------------------------
--Redis配置
_M.db.redis = {
	type = "redis",
	host = sys.env.REDIS_HOST or "192.168.50.205",
	port = sys.env.REDIS_PORT or 6379,
	--password = sys.env.REDIS_PASSWORD or 'Laiyx@Zhuoxun.com',
	db_index = 0,
	concurrency = 1000, --最大读写并发数,默认1000
}
--]=]

--[=[平台服务配置
_M.zcenter = {
	gate = sys.env.APIGATEHOST or 'http://apisix.intranet.cn',		--网关地址
	id = sys.env.APIGATE_ID or 0,									--服务ID
	name = sys.env.APIGATE_NAME or 'servername',					--服务名
	key = sys.env.APIGATE_SECRET or '',								--服务密钥
	host = sys.env.HOST_IP or '',									--服务地址，非必需，当无此值时，使用本机IP
	port = sys.env.LISTEN_PORT or 80								--服务端口，非必需，当无此值时，使用_M.http_ports[1]
}

if _M.env == 'test' then
	--_M.zcenter.gate = 'http://api.intranet.cn'
	_M.zcenter.gate = 'http://192.168.60.107'
elseif _M.env == 'prod' then
	_M.zcenter.gate = 'https://api.zxlyx.cn'
end

--可选
--根据环境配置初始化配置
_M.init = function (env)
	console(core.cjson.encode(env))
end
--]=]

return _M
