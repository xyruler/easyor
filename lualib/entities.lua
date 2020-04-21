--[[
实体对象管理
--]]
local config = config
local entity = core.entity

local entities = {}
local entities_on_message = {}

local _M = {}

local _new_entity = function(eid,et)
	if not entities_on_message[et] then return false end

	local ent = entity:new(eid,et)
	
	local ok = ent:init(entities_on_message[et])
	return ent
end

_M.get = function(eid,et)
	et = et or 0
	entities[et] = entities[et] or {}

	if not entities[et][eid] then
		entities[et][eid] = _new_entity(eid,et)
		if not entities[et][eid] then return false,'new entity error' end
	end
	
	return entities[et][eid]
end

_M.set = function(eid,et,entity)
	if not eid then return false end
	et = et or 0
	entities[et] = entities[et] or {}
	entities[et][eid] = entity
	
	return true
end

_M.del = function(eid,et)
	if not eid then return true end
	et = et or 0
	if entities[et] then entities[et][eid] = nil end
	
	return true
end

_M.set_entity_params = function(et,on_message)
	et = et or 0
	entities_on_message[et] = on_message
end

return _M