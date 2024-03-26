--[[
本文件修改后，需重启服务才能生效
本模块中，不能直接执行require语句
--]]

local _M = {}
_M.debug = true		--调试状态，生产时请设置为false

_M.env = sys.env.DEPLOY_ENV or 'dev'

--[[环境变量
_M.sys_env_list = {
	'PROJECT_NAME', 'PROJECT_VERSION', 'DEPLOY_ENV', 'HOST_IP', 'LISTEN_PORT', 'EXPOSE_PORT',
	'MYSQL_MASTER_HOST', 'MYSQL_MASTER_PORT', 'MYSQL_MASTER_USERNAME', 'MYSQL_MASTER_PASSWORD',
	'MYSQL_SLAVE_HOST', 'MYSQL_SLAVE_PORT', 'MYSQL_SLAVE_USERNAME', 'MYSQL_SLAVE_PASSWORD',
	'REDIS_HOST', 'REDIS_PORT', 'REDIS_PASSWORD',
	'APIGATEHOST', 'APIGATEPORT', 'APIGATE_ID', 'APIGATE_NAME', 'APIGATE_SECRET',
}
--]]
-------------------------
--服务配置
--是否为单一进程服务
_M.singleton_work = true
--_M.worker_num = sys.env.WORKER_NUM or 'auto'
--服务使用的协议
--_M.use_tcp = true
--_M.use_udp = true
_M.use_http  = true
_M.use_websocket = true
--_M.use_websocket_autobalance = true
--端口设置
--_M.tcp_ports = {sys.env.LISTEN_PORT or 8080}
--_M.udp_ports = {sys.env.LISTEN_PORT or 8081}
_M.http_ports = {sys.env.LISTEN_PORT or 80}

_M.status = {
	OK = 0,
	FAILED = -1,
	SIGNERR = 100,
	URLERR = 101,
	ARGSERR = 102,
}

---------------------------
--[=[phase开关
--是否重载相应的处理过程，重载方法在app.lua中定义
_M.phase = {}
_M.phase.preread = false
_M.phase.rewrite = false
_M.phase.access = false
_M.phase.header_filter = false
_M.phase.body_filter = false
_M.phase.log = false
--]=]

---------------------------
--路由配置
--根目录设置
_M.route_root = 'route'		--默认为'api'
--_M.route_prefix = ''		--路由前缀

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

--[[设置http头信息
_M.http_add_headers = {
	"'Access-Control-Allow-Origin' '*'",
	"'Access-Control-Allow-Methods' 'GET, POST, OPTIONS'",
	"'Access-Control-Allow-Headers' 'Content-Type,XFILENAME,XFILECATEGORY,XFILESIZE'",
}
--]]

--[[配置特殊的路由
_M.http_static_file = {					--静态文件服务
	exts = 'gif|jpg|jpeg|bmp|png|ico|txt|js|css|html|htm',	--文件类型
	root = '',												--根目录
	expires = '7d',											--过期时间,默认7天
	add_headers = {											--添加头数据,可选
		"'Access-Control-Allow-Origin' '*'",
		"'Access-Control-Allow-Methods' 'GET, POST, OPTIONS'",
		"'Access-Control-Allow-Headers' 'Content-Type,XFILENAME,XFILECATEGORY,XFILESIZE'",
	},
}

_M.http_locations = {
	wxpaycallback = {
		mode = '=',						--路径匹配规则，参考nginx
		path = '/weixin/pay/callback',	--访问路径
		real_path = 'api/pay/weixin',	--内部路径
		allow = { 						--允许访问的ip列表,可选
			'wx_ip_1',
			'wx_ip_2',
		}，
		add_headers = {					--添加头数据,可选
			"'Access-Control-Allow-Origin' '*'",
			"'Access-Control-Allow-Credentials' 'true'",
			"'Access-Control-Allow-Methods' 'GET'",
			"'Access-Control-Allow-Methods' 'POST'",
			"'Access-Control-Allow-Headers' 'Content-Type,XFILENAME,XFILECATEGORY,XFILESIZE'",
		},		
	},
	zfbpaycallback = {
		mode = '^~',
		path = '/zfb/pay/(.*)',
		real_path = 'api/pay/zfb/$1',	--可以使用变量，参考nginx
	},
}
--]]

----------------------------
--[=[缓存配置
_M.caches = {
	my_cache = {
		share_dict_size = '10m',	--共享内存大小
		lru_size = 10000,			--worker中缓存的最大对象个数
		ttl = 3600,					--缓存有效时间，单位秒
		neg_ttl = 60,				--缓存中未命中对象有效时间，单位秒
		--[[缓存锁参数 - 可选参数
		resty_lock_opts = {
			timeout = 5,
			exptime = 30,
			step = 0.001,
			ratio = 2,
			max_step = 0.5,
		},
		-- 设置自定义锁 - 可选参数
		do_lock = function(lock_key) return lock,err end -- lock = {unlock = function() end}
		read_lock_on = true,
		--]]
		--l1_serializer = function(value) return value,err end,	--值序列化函数,从sharedict中取出后存入lua内存时调用 --可以是模块路径
		
		--[[- 可选参数
		--当缓存中没有数据时，获取数据的方法
		--ctx:配置数据
		--key:get方法传入的key值
		get_from_db = function(ctx,key)	--可以是模块路径
			return value,err
		end,
		--]]
		--[[- 可选参数
		--当有数据更改时，保存数据的方法
		--ctx:配置数据
		--key:set方法传入的key值
		--value:set方法传入的value值
		--bnew:是否为新增key
		save_to_db = function(ctx,key,value,bnew)	--可以是模块路径
			return newkey,value,err
		end,
		--]]
	},
}
--]=]

----------------------------
--[=[DB配置
_M.db = {}
--Mysql配置
_M.db.example_mysql = {
	type = 'mysql',
	host = sys.env.MYSQL_MASTER_HOST or '127.0.0.1',
	port = sys.env.MYSQL_MASTER_PORT or 3306,
	user = sys.env.MYSQL_MASTER_USERNAME or 'root',
	password = sys.env.MYSQL_MASTER_PASSWORD or 'xxxxx',
	database = 'xxxx',
	--concurrency = 4,		--最大读写并发数,默认100
}

----------------------------
--Redis配置
_M.db.example_redis = {
	type = 'redis',
	host = sys.env.REDIS_HOST or '127.0.0.1',
	port = sys.env.REDIS_PORT or 6379,
	--password = sys.env.REDIS_PASSWORD or 'Laiyx@Zhuoxun.com',
	db_index = 0,
	--concurrency = 1000,	--最大读写并发数,默认1000
}
--]=]

----------------------------
--[=[Kafka配置
_M.kafka = {}

--Kafka Producer 配置
_M.kafka.producer = {
	type = 'producer',		
	broker_list = {
		{host = '127.0.0.1', port = 9092},
	},
	config = {
	},
	topic_config = {
		default = {
		},
		--topic_name = {},
	},
}

--Kafka Consumer 配置
_M.kafka.consumer = {
	type = 'consumer',
	broker_list = {
		{host = '127.0.0.1', port = 9092},
	},
	group = 'mygroup',	--groupid
	config = {
		max_wait_time = 10000, --ms 默认10s
		min_bytes = 1,   --最小读取字节数
		max_bytes = 1024,  --单次最大数据长度
	},
	topic_list = {		--监听主题列表
		'topic1',
		'topic2',
	},
	dofun = 'api.dofun',	--消息处理函数
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