--[[
日志
--]]
local ngx_thread_spawn = ngx.thread.spawn
local ngx_thread_wait = ngx.thread.wait
local ngx_thread_kill = ngx.thread.kill

local _M = {version = 0.1}

_M.spawn = ngx_thread_spawn
_M.wait = ngx_thread_wait
_M.kill = ngx_thread_kill

_M.pool = require 'core.thread.pool'
_M.group = require 'core.thread.group'
_M.call = require 'core.thread.call'

return _M
