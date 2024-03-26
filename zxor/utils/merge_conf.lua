--[[
合并配置
--]]
sys = {}
sys.env = setmetatable({},{
	__index = function(self,key)
		return os.getenv(key)
	end
})

ngx_config = require 'utils.conf.default'

local env = require 'utils.env'

--检查必需的文件
local check_files = function()
	local files = {
		'config.lua',
		'app.lua',
	}
	
	for _,file in ipairs(files) do
		if not env.exist(env.workpath .. '/' .. file) then return false end
	end
	
	return true
end

local init_sys_env_list = function(cfg)
	local list = {}
	for _, e in ipairs(cfg.sys_env_list or {}) do
		local has = false
		for _,n in ipairs(list) do
			if n == e then
				has = true
				break
			end
		end
		if not has then
			list[#list + 1] = e
		end
	end

	ngx_config.sys_env = list
end

local init_resolver = function(cfg)
	if cfg.resolver then
		ngx_config.resolver = cfg.resolver
	end
end

local init_lua_config = function(cfg)
	ngx_config.lua = ngx_config.lua or {}
	if cfg.max_running_timers then	--计数器配置
		ngx_config.lua.lua_max_running_timers = cfg.max_running_timers
	end
	
	if cfg.lua_max_pending_timers then	--计数器配置
		ngx_config.lua.lua_max_pending_timers = cfg.lua_max_pending_timers
	end
end

local init_server_config = function(cfg)
	local stream_on = cfg.use_tcp or cfg.use_udp	--是否开启stream模块
	local http_on = cfg.use_http					--是否开启http模块
	local tcp_ports = cfg.use_tcp and cfg.tcp_ports or nil	--tcp监听端口
	if ngx_config.tcp_ports and tcp_ports then
		tcp_ports = ngx_config.tcp_ports
	end
	local udp_ports = cfg.use_udp and cfg.udp_ports or nil	--udp监听端口
	if ngx_config.udp_ports and udp_ports then
		udp_ports = ngx_config.udp_ports
	end
	local http_ports = cfg.use_http and cfg.http_ports or nil	--http监听端口
	if ngx_config.http_ports and http_ports then
		http_ports = ngx_config.http_ports
	end
	
	ngx_config.phase = cfg.phase or {}	--流程控制开关
	if cfg.cors and cfg.cors.allow then
		ngx_config.phase.header_filter = ngx_config.phase.header_filter or true
		ngx_config.phase.rewrite = ngx_config.phase.rewrite or true
	end

	if not stream_on and not http_on then
		stream_on = true
		tcp_ports = nil
		udp_ports = nil
	end

	--将配置融合到最终配置中
	if stream_on then
		ngx_config.stream = {}
		ngx_config.stream.tcp = tcp_ports
		ngx_config.stream.udp = udp_ports
		ngx_config.stream.proxy = cfg.stream_proxy or nil
	end
	
	if http_on then
		ngx_config.http = {}
		ngx_config.http.server = {}
		ngx_config.http.server.listen = http_ports
		
		--http中主路由
		ngx_config.http.server.location_main = {}
		ngx_config.http.server.location_main.add_headers = cfg.http_add_headers or {}
		ngx_config.http.server.location_main.proxy = cfg.http_proxy or nil
		
		--静态文件访问
		ngx_config.http.server.location_file = cfg.http_static_file
		if not ngx_config.http.server.location_file and cfg.http_static_file_exts and #cfg.http_static_file_exts > 0 then
			ngx_config.http.server.location_file = {}
			ngx_config.http.server.location_file.exts = cfg.http_static_file_exts
			if cfg.http_static_file_root and #cfg.http_static_file_root > 0 then
				ngx_config.http.server.location_file.root = cfg.http_static_file_root
			end
			ngx_config.http.server.location_file.expires = cfg.http_static_file_expires or '7d'
			
			if cfg.http_static_file_allow_cross_domain then
				ngx_config.http.server.location_file.add_headers = {}
				ngx_config.http.server.location_file.add_headers[1] = "'Access-Control-Allow-Origin' '*'"
			end
		end
		
		--其它自定义路由
		ngx_config.http.server.locations = cfg.http_locations
	end
end

local init_sharedict = function(cfg)
	if cfg.caches then	--缓存配置，需要在nginx config中配置share dicts
		local cache_num = 0
		ngx_config.share_dicts = ngx_config.share_dicts or {}
		for k,v in pairs(cfg.caches) do
			ngx_config.share_dicts[k] = v.share_dict_size
			local ipc_size = math.ceil((v.lru_size or 10000) * 100 / 1000000) .. 'm'
			if v.ipc_shm then
				ngx_config.share_dicts[v.ipc_shm] = ipc_size
			elseif not v.ipc_redis and not v.ipc then
				ngx_config.share_dicts['sys_cache_ipc_' .. k] = ipc_size
			end
			cache_num = cache_num + 1
		end
		if cache_num > 0 then	--配置缓存同步使用的缓存
			ngx_config.share_dicts['sys_cache_miss'] = '10m'
			ngx_config.share_dicts['sys_cache_locks'] = '10m'
			--ngx_config.share_dicts['sys_cache_ipc'] = '10m' --每个缓存使用自己的ipc
		end
	end
end

local init_client_buff = function(cfg)
	if cfg.client_buffer then
		ngx_config.client_buffer = ngx_config.client_buffer or {}
		for k,v in pairs(cfg.client_buffer) do
			ngx_config.client_buffer[k] = v
		end
	end
end

local init_env = function(cfg)
	if cfg.singleton_work then
		ngx_config.worker_num = 1
	elseif not ngx_config.worker_num and cfg.worker_num then
		ngx_config.worker_num = cfg.worker_num
	end
	env.loglevel = ngx_config.loglevel or env.loglevel or cfg.loglevel or 'info'
	env.logpath = ngx_config.logpath or env.logpath
	ngx_config.thread_pools = cfg.thread_pools or ngx_config.thread_pools
end

local _M = function()
	--如果缺少必需的文件，则退出
	if not check_files() then return false end
	
	--项目中的config
	local cfg = require 'config'
	pcall(require,'config_online')
	
	init_env(cfg)
	init_client_buff(cfg)
	init_sys_env_list(cfg)
	init_resolver(cfg)
	init_server_config(cfg)
	init_lua_config(cfg)
	init_sharedict(cfg)

	return true
end

return _M