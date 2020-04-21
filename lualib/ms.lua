--[[
ms框架预加载
--]]
local _M = {}

--消息定义
_M.message = {
	head = require 'ms.message.head',
	receive = require 'ms.message.receive',
	opts = require 'ms.message.opts',
}

--controller
_M.controller = {
	manager = require 'ms.controller.manager',
	connect = require 'ms.controller.connect',
	service = {
		on_close = require 'ms.controller.service.on_close',
		on_message = require 'ms.controller.service.on_message',
	},
	commands = require 'ms.controller.commands',
}

--service
_M.service = {
	register = require 'ms.service.register',
	message = {
		request = require 'ms.service.message.request',
		broadcast = require 'ms.service.message.broadcast',
		respond = require 'ms.service.message.respond',
		push = require 'ms.service.message.push',
	}
}

return _M