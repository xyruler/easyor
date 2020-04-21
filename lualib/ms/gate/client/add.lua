--[[
添加客户端
--]]
local config = config
local cache = core.cache
local entities = entities

local bindentity = require 'ms.service.bindentity'
local del_client = require 'ms.gate.client.del'

local bind = function(client,userid)
	client.userid = userid
	cache.set('ms.gate.user.' .. client.userid,client)
	
	local ok,rs = bindentity(userid,config.channel)
	if ok then
		local entity = entities.get(userid,config.channel)
		entity.client = client
	end
	
	return ok,rs
end

local _M = function(client,uid)
	client.id = (cache.get('ms.gate.client.num') or 0) + 1
	cache.set('ms.gate.client.num',client.id)
	cache.set('ms.gate.client.' .. client.id,client)
	return bind(client,uid)
end

return _M