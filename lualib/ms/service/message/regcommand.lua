--[[
设置广播消息监听
--]]
local config = config
local route = route
local channel = config.channel

local _M = function(command,api)
	
	config.cmdlist = config.cmdlist or {}
	config.cmdlist[channel] = config.cmdlist[channel] or {}
	config.cmdlist[channel][command] = api

end

return _M
