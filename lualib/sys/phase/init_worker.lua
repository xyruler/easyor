core = require 'core'
config = require 'config'
if ngx.config.subsystem == "http" then
	cache = require 'cache'
	db = require 'db'
end
route = require 'route'
entities = require 'entities'
ms = require 'ms'
app = require 'app'

kafka = nil

if not config.debug then
	core.reload = require
end

local console = core.log.info
if not app.init then
	app.init = function()
		console('app init ...')
	end
end

local _M = function()
	kafka = require 'kafka'
	console('init worker ...')
	app.init()
	console('init worker finished.')
	
	for k,consumer in pairs(kafka or {}) do
		if consumer.type == 'consumer' then
			console('start kafka consumer name = ',k, ' in worker ', ngx.worker.id())
			consumer:run()
		end
	end
	
end

return _M