--[[
公共方法加载
--]]
local _M = {
	ffi			= require('ffi'),
	table		= require('core.table'),
	class		= require('core.class'),
	reload		= require('core.reload'),
	loadscript	= require('core.loadscript'),
	cjson		= require('core.cjson'),
	go			= require('core.go'),
	log			= require('core.log'),
	thread		= require('core.thread'),
	http		= require('core.http'),
	clone		= require('core.clone'),
	respond		= require('core.respond'),
	phase		= require('core.phase'),
	dns			= require('core.dns'),
	redis		= require('core.redis'),
	memcached 	= require('core.memcached'),
	cache 		= require('core.innercache'),	--内部缓存，仅当前work进程中使用
	entity		= require('core.entity'),
	websocket 	= {
		server 	= require('core.websocket.server'),
		client 	= require('core.websocket.client'),
	},
	tcp		 	= {
		server 	= require('core.tcp.server'),
		client 	= require('core.tcp.client'),
	},
	binary 		= require('core.binary'),
	string		= {
		split 	= require('core.string.split'),
		urlencode = require('core.string.urlencode'),
		urldecode = require('core.string.urldecode'),
	},
	file 		= {
		load 	= require('core.file.load'),
		save	= require('core.file.save'),
		--read	= require('core.file.read'),
		--write	= require('core.file.write'),
		append	= require('core.file.append'),
	},
	tools 		= {
		random 	= require('core.tools.random'),
		time 	= require('core.tools.time'),
	},
	shell		= {
		execute = require('core.shell.execute'),
		exist 	= require('core.shell.exist'),
		getfiles = require('core.shell.getdirfiles'),
	},
}

if ngx.config.subsystem == "http" then
	_M.mysql = require('core.mysql.mysql')
end

return _M