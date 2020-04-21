--[[
负载策略注册
--]]
local ffi = core.ffi
local manager = require 'ms.controller.manager'

local _M = function(service,head)
	if head.EntityId > 0 then
		local ok,oldservice = manager.add_balance(head.EntityId,head.EntityType,service)
		if ok then
			--如果原有该实体的负载，通知原服务
			if oldservice and oldservice ~= service and oldservice.sid then
				local h,s = msghead.get()
				h.Opt = msgopts.broadcast
				h.ToChannel = mychannel
				h.To = oldservice.sid
				h.FromChannel = mychannel
				h.From = 0
				h.EntityId = head.EntityId
				h.EntityType = head.EntityType
				h.Command = head.Command
				h.Cbk = 0
				oldservice:send(ffi.string(h,s) .. '1')
			end
			return true
		else
			return false,'add balance info failed.'
		end
	else
		return false,'the EntityId is zero.'
	end
end

return _M
