--[[
消息处理
--]]
local respond = require 'ms.service.message.respond'
local console = core.log.info

local channel = config.channels.controller or 0
local commands = {
	entity_balance_cancel = 2,
}

local entities = entities

local on_entity_balance_cancel = function(args)
	if not args or not args.entity then return respond(-1,{},'wrong entity') end
	entities.del(args.entity.eid,args.entity.et)
	return respond(0,{},'ok')
end

local _M = function()
	route.set('cmd_' .. channel .. '_' .. commands.entity_balance_cancel,on_register_entity_balance_cancel)
end

return _M