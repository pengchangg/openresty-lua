--[[
线上配置
--]]

if ngx_config then
	--调整nginx配置
	--参照 utils.conf.default
	--[[ eg.
	ngx_config.user = 'root root'
	ngx_config.worker_num = 1

	ngx_config.resolver = {
		list = {
			'100.100.2.136',
			'100.100.2.138',
			'114.114.114.114',
			'8.8.8.8',
		},
		--ipv6 = false,
		timeout = 5,
	}

	ngx_config.access_log = {
		format = 'main',        --access_log 日志格式
		buffer = '32k',         --access_log 缓存大小
	}

	ngx_config.loglevel = 'info'
	ngx_config.logpath = ''

	--是否允许跨域
	ngx_config.http_allow_cross_domain = true

	--对外服务端口号
	ngx_config.tcp_ports = {8080}
	ngx_config.udp_ports = {8081}
	ngx_config.http_ports = {80}
	--]]
end

-- app 相关配置
local app_config = require 'config'
-- app debug 模式
app_config.debug = false

-- db配置
--[[
app_config.db.example_mysql = {
	type = 'mysql',
	host = '127.0.0.1',
	port = 3306,
	user = 'root',
	password = 'xxxxx',
	database = 'xxxx',
	--concurrency = 4,		--最大读写并发数,默认100	
}

app_config.db.example_redis = {
	type = 'redis',
	host = '127.0.0.1',
	port = 6379,
	--password = 'Laiyx@Zhuoxun.com',
	db_index = 0,
	--concurrency = 1000,	--最大读写并发数,默认1000
}
--]]

