--[[
服务注册
--]]
local commands = {
	register_service = 1,
	register_entity_balance = 2,
}

local _M = {
	[commands.register_service] = require 'ms.controller.commands.register',
	[commands.register_entity_balance] = require 'ms.controller.commands.addbalance',
}

return _M
