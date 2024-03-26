--[[
系统各过程处理函数
--]]
sys = {}
sys.phase = {}

local default = function()
    core.log.info('not init')
end

sys.phase.init 				= require 'sys.phase.init'
sys.phase.init_worker 		= require 'sys.phase.init_worker'
sys.phase.exit_worker		= default
sys.phase.ssl_client_hello	= default
sys.phase.ssl_certificate 	= default
sys.phase.preread 			= default
sys.phase.server_rewrite	= default
sys.phase.rewrite 			= default
sys.phase.set 				= default
sys.phase.access 			= default
sys.phase.content 			= default	--content_for_stream
sys.phase.route 			= default	--content for http
sys.phase.wsconnect 		= default	--content for ws -- route: /connect
sys.phase.balancer 			= default
sys.phase.header_filter 	= default
sys.phase.body_filter 		= default
sys.phase.log 				= default
sys.phase.ssl_session_fetch = default
sys.phase.ssl_session_store = default

sys.init_phase = function()
	sys.phase.exit_worker 		= require 'sys.phase.exit_worker'
	sys.phase.ssl_client_hello	= require 'sys.phase.ssl_client_hello'
	sys.phase.ssl_certificate 	= require 'sys.phase.ssl_certificate'
	sys.phase.ssl_session_fetch = require 'sys.phase.ssl_session_fetch'
    sys.phase.ssl_session_store = require 'sys.phase.ssl_session_store'
	sys.phase.set				= require 'sys.phase.set'
	sys.phase.preread 			= require 'sys.phase.preread'
	sys.phase.server_rewrite	= require 'sys.phase.server_rewrite'
	sys.phase.rewrite 			= require 'sys.phase.rewrite'
	sys.phase.access 			= require 'sys.phase.access'
	sys.phase.content 			= require 'sys.phase.content'	--content_for_stream
	sys.phase.route 			= require 'sys.phase.route'		--content for http
	sys.phase.wsconnect 		= require 'sys.phase.wsconnect'	--content for ws -- route: /connect
	sys.phase.balancer 			= require 'sys.phase.balancer'
	sys.phase.header_filter 	= require 'sys.phase.header_filter'
	sys.phase.body_filter 		= require 'sys.phase.body_filter'
	sys.phase.log 				= require 'sys.phase.log'
end