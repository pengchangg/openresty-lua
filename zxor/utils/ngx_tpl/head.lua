--[[
nginx config 头部配置
--]]

local env = require 'utils.env'
---@diagnostic disable-next-line: different-requires
local template = require 'lualib.resty.template'

local _M = {}

local tpl = [==[
{% if env.daemon == 'off' then %}
daemon off;
{% end %}
{% if config.sys_env then %}
{% for _, env_name in ipairs(config.sys_env) do %}
env {* env_name *};
{% end %}

{% end %}
master_process on;
user {* config.user or 'root' *};
worker_processes {* config.worker_num or env.cpunum or 'auto' *};
{% if env.os_name == "Linux" then %}
worker_cpu_affinity {* config.worker_cpu_affinity or 'auto' *};
{% end %}
{% if config.worker_priority then %}
worker_priority {* config.worker_priority *};
{% end %}

{% if env.indocker then %}
error_log /usr/local/openresty/nginx/logs/error.log {* env.loglevel *};
{% else %}
error_log {* env.logpath *}/error_{* env.project *}.log {* env.loglevel *};
{% end %}
pid {* env.logpath *}/nginx_{* env.project *}.pid;

worker_rlimit_nofile {* config.worker_rlimit_nofile or env.ulimit or 65535 *};
{% if config.thread_pools then %}

{% for poolname,poolconf in pairs(config.thread_pools) do %}
thread_pool {* poolname *} threads={* poolconf.threads or 32 *} max_queue={* poolconf.max_queue or 65536 *};
{% end %}
{% end %}

pcre_jit on;

events {
    accept_mutex {* config.accept_mutex and 'on' or 'off' *};
    use {* config.eventtype or 'epoll' *};
    worker_connections {* config.worker_connections or env.ulimit or 20480 *};
    {% if config.multi_accept then %}
    multi_accept on;
	{% end %}
}

 {% if config.open_core then %}
worker_rlimit_core  {* config.open_core *};
working_directory {* env.workpath *};
{% end %}
 {% if config.worker_shutdown_timeout then %}
#worker_shutdown_timeout {* config.worker_shutdown_timeout *};
{% end %}
]==]

_M.make = function(config)
	return template.compile(tpl)({
		config = config,
		env = env
	})
end

return _M

