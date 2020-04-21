--[[
删除客户端
--]]

local cache = core.cache
local entities = entities
local config = config

local del_entity = function(client)
	if client.userid then
		cache.del('ms.gate.user.' .. client.userid)
		entities.del(client.userid,config.channel)
		client.userid = nil
	end
end

local _M = function(client,keep)
	del_entity(client)
	
	if not keep and client.id then
		cache.del('ms.gate.client.' .. client.id)
	end

end

return _M