--[[
推送消息
--]]
local channel_gate = 1 
if config.channels and config.channels.gate then
	channel_gate = config.channels.gate
end
local send = require 'ms.service.message.send'
local msgopts = require 'ms.message.opts'
local opt = msgopts.pushtogate

local _M = function(userid,command,data)
	return send(channel_gate,command,data,userid,channel_gate,opt)
end

return _M
