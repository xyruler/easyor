--[[
消息处理
--]]
local respond = require 'ms.service.message.respond'
local on_entity_message = require 'ms.service.listener.on_entity_message'

local console = core.log.info

local _M = function(cmdlist)
	console('register listen message')
	
	local channels = {}
	channels[config.channel] = 1
	
	for channel,cmds in pairs(cmdlist or {}) do
		channels[channel] = 1
		for cmd,api in pairs(cmds) do
			route.set('cmd_' .. channel .. '_' .. cmd,api)
		end
	end
	
	for channel,_ in pairs(channels) do
		entities.set_entity_params(channel,on_entity_message)
	end
end

return _M