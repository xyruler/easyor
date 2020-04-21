--[[
服务启动
--]]
local cache = core.cache
local config = config
local console = core.log.info
local listener = require 'ms.service.listener'
local register = require 'ms.service.register'
local request = require 'ms.service.message.request'
local broadcast = require 'ms.service.message.broadcast'
local respond = require 'ms.service.message.respond'
local push = require 'ms.service.message.push'

local register_cmds = require 'ms.service.listener.register_cmds'
local register_controller_cmds = require 'ms.service.listener.register_controller_cmds'

local _M = function()
	ms.service = ms.service or {}
	ms.service.listener = listener()
	ms.service.register = register
	ms.service.message = {
		request = request,
		broadcast = broadcast,
		push = push,
		respond = respond,
	}
	
	local ok,rs = register(ms.service.listener)
	if ok then
		console('register listener success. --> listener.id = ',rs)
	else
		console('register to controller failed. --> ',rs)
		ms.service.listener:close()
	end
	
	register_controller_cmds()
	register_cmds(config.cmdlist)
end

return _M