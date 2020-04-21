--[[
公共方法加载
--]]
local _M = {
	ffi			= require('ffi'),
	class		= require('core.class'),
	reload		= require('core.reload'),
	cjson		= require('core.cjson'),
	go			= require('core.go'),
	log			= require('core.log'),
	http		= require('core.http'),
	clone		= require('core.clone'),
	respond		= require('core.respond'),
	phase		= require('core.phase'),
	dns			= require('core.dns'),
	redis		= require('core.redis'),
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
}

if ngx.config.subsystem == "http" then
	_M.mysql = require('core.mysql.mysql')
end

return _M