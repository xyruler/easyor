--[[
广播消息
--]]
local send = require 'ms.service.message.send'
local msgopts = require 'ms.message.opts'
local opt = msgopts.broadcast

local _M = function(channel,command,data,entityid,entitytype)
	return send(channel,command,data,entityid,entitytype,opt)
end

return _M
