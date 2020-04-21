--[[
设置广播消息监听
--]]
local config = config
local route = route

local _M = function(channel,command,api)
	
	config.listen_list = config.listen_list or {}
	config.listen_list[channel] = config.listen_list[channel] or {}
	if config.listen_list[channel] ~= 'all' then
		local bin = false
		for _,v in ipairs(config.listen_list[channel]) do
			if v == command then
				bin = true
				break
			end
		end
		if not bin then
			config.listen_list[channel][#config.listen_list[channel] + 1] = command
		end
	end
	
	config.cmdlist = config.cmdlist or {}
	config.cmdlist[channel] = config.cmdlist[channel] or {}
	config.cmdlist[channel][command] = api
	
	return true
end

return _M
