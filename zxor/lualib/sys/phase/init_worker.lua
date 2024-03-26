---@diagnostic disable: assign-type-mismatch
core = require 'core'
local loginfo = core.log.info

worker = {}

config = false
zcenter = false
db = false
cache = false
route = false
entities = false
kafka = false
app = {}

local init_global_vars = function()
	if config.env ~= 'dev' then
		config.debug = false
	end

	zcenter = require 'zcenter'
	if zcenter then
		zcenter.init()
	end

	if config.init then
		config.init(zcenter and zcenter.env or nil)
	end

	if ngx.config.subsystem == "http" then
		db = require 'db'
		cache = require 'cache'
	end

	route = require 'route'
	entities = require 'entities'

	local _,_app = pcall(require,'app')

	if type(_app) == 'string' then
		core.log.error('ERROR: ',_app)
	else
		app = _app
	end

	if not app then app = {} end

	if not app.init then
		app.init = function()
			loginfo('app init ...')
		end
	end

	if config.kafka then
		kafka = require 'kafka'
	end
end

local on_worker_shutdown = function()
	worker.killed = true

	if entities then
		entities.clear('on_worker_shutdown')
	end

	if app and app.on_worker_shutdown then
		app.on_worker_shutdown()
	end

	core.log.record('worker','worker_shutdown')
end

local _init_worker = function()
	init_global_vars()

	sys.init_phase()

	-- init cache subscribe
	for _,c in pairs(cache or {}) do
		if type(c) == 'table' and c.cache and c.cache.subscribe then
			c.cache.subscribe()
		end
	end

	if config.use_websocket then
		app.pool_for_ws_request = core.thread.pool:new(config.use_websocket_maxthreadnum or 500)
		core.go(0,function()
			app.pool_for_ws_request:run()
		end)
		route.set('/connect',sys.phase.wsconnect)
	end

	loginfo('init worker ...')
	app.init()
	loginfo('init worker finished.')
	core.log.record('worker','worker_init finished -> worker id = ' .. ngx.worker.id())

	-- load route
	local files = core.shell.getfiles(config.route_root or 'api','lua')
	for _,file in ipairs(files) do
		local p1,p2 = string.find(file,config.route_root or 'api')
		if p1 and p2 then
			route.get(string.sub(file,p2 + 1))
		end
	end

	core.go(1,function()
		for k,consumer in pairs(kafka or {}) do
			if consumer.type == 'consumer' then
				loginfo('start kafka consumer name = ',k, ' in worker ', ngx.worker.id())
				consumer:run()
			end
		end
	end)
end

local _M = function()
	math.randomseed(ngx.now())

	config = require 'config'
	pcall(require,'config_online')

	if config.zcenter or config.init then
		core.go(0,_init_worker)
	else
		_init_worker()
	end

	ngx.timer.every(3,function(premature)
		if premature then
			on_worker_shutdown()
		end
	end)
end

return _M