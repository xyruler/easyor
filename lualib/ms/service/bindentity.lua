--[[
将本服务注册为指定对象的指定处理服务
--]]
local tonumber = tonumber
local cjson = core.cjson

local request = ms.service.message.request
local channel_controller = config.channels.controller
local register_entity_balance_cmd = 2

local _M = function(entityid,entitytype)
	if not entityid or not entitytype then return false end
	if entityid == 0 then return false end
	
	return request(channel_controller,register_entity_balance_cmd,0,entityid,entitytype)
end

return _M
