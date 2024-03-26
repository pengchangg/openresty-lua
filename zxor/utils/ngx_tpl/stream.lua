--[[
nginx config stream配置
--]]

local env = require 'utils.env'
local template = require 'lualib.resty.template'

local _M = {}

--[[upstream
    {* config.lua and config.lua.lua_socket_log_errors and 'lua_socket_log_errors ' .. config.lua.lua_socket_log_errors .. ';' or '' *}

	{% for name,data in pairs(config.upstream or {}) do %}
    upstream  {* name *}  { 
	{% for _,value in ipairs(data.servers) do %}
        server    {* value *};
	{% end %}
	{* data.mode and data.mode .. ';' or '' *}
	{% if data.balancer_by_lua_file then %}
        balancer_by_lua_block {
	    local balancer = require "{* data.balancer_by_lua_file *}"
            if type(balancer) == 'function' then
                balancer()
            end
        }
	{% end %}
	{* data.keepalive and 'keepalive ' .. data.keepalive .. ';' or '' *}
    }
	{% end %}
--]]

local tpl = [==[
stream {
    lua_package_path "{* env.workpath *}/?.lua;{* env.workpath *}/?/init.lua;{* env.myorlualib *}/?.lua;{* env.myorlualib *}/?/init.lua;{* env.orlualib *}/?.lua";
    lua_package_cpath "{* env.workpath *}/?.so;{* env.myorlualib *}/?.so;{* env.orlualib *}/?.so";
	
    {% for name,size in pairs(config.share_dicts or {}) do %}
    lua_shared_dict {* name *} {* size *};
    {% end %}

    init_by_lua_block {
        require "sys.core"
        core.myor_prefix = '{* env.myorpath *}'
        core.work_path = '{* env.workpath *}'
        sys.env = {}
        {% for _, en in ipairs(config.sys_env or {}) do %}
        sys.env['{* en *}'] = os.getenv('{* en *}')
        {% end %}
        sys.phase.init({% if env.indocker then %}true{% end %})
    }

    init_worker_by_lua_block {
        sys.phase.init_worker()
    }
    {% if config.phase and config.phase.preread then %}
    
    preread_by_lua_block {
        sys.phase.preread()
    }
	{% end %}
    {% if config.phase and config.phase.log then %}
    
    log_by_lua_block {
        sys.phase.log()
    }
    {% end %}
    {% if config.stream.proxy then %}
    
    upstream stream_backend {
        keepalive {* config.stream.proxy.keepalive or 320 *};
        keepalive_requests {* config.stream.proxy.keepalive_requests or 1000 *};
        keepalive_timeout {* config.stream.proxy.keepalive_timeout or '60s' *};

        balancer_by_lua_block {
            sys.phase.balancer()
        }
    }
    {% end %}
    {% if config.stream.tcp or config.stream.udp then %}
    
    server {
        {% for _, port in ipairs(config.stream.tcp or {}) do %}
        listen {*port*};
        {% end %}
        {% for _, port in ipairs(config.stream.udp or {}) do %}
        listen {*port*} udp;
        {% end %}

        {% if config.stream.proxy then %}
        proxy_pass  main_backend;
        {% else %}
        content_by_lua_block {
            sys.phase.content()
        }
        {% end %}
    }
	{% end %}
}

]==]

_M.make = function(config)
	return template.compile(tpl)({
		config = config,
		env = env
	})
end

return _M
