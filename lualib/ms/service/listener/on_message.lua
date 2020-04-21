--[[
消息处理
--]]
local ffi = core.ffi
local console = core.log.info 
local cache = core.cache
local config = config
local route = route
local spawn = ngx.thread.spawn
local console = core.log.info

local entities = entities

local msgopts = require 'ms.message.opts'
local receive = require 'ms.message.receive'
local respond = require 'ms.service.message.respond'

local _M = function(listener,msg)
	cache.set('ms.service.receive.count',(cache.get('ms.service.receive.count') or 0) + 1)
	--解析消息
	local head,data,err = receive(msg)
	if not head or not msg then
		console('receive one wrong message from controller --> err = ', err)
		return false,'wrong data' .. err
	end
	
	--console('receive one message -> opt = ',head.Opt, ' channel = ', head.FromChannel, ' Command = ', head.Command, ' entid = ',tonumber(head.EntityId), ' enttype = ',head.EntityType)
	
	if head.Opt == msgopts.respond or head.Opt == msgopts.haserror then
		--回复的消息
		local callback = nil
		--获取回调对象
		if head.Cbk > 0 then
			--callback = cache.get('ms.service.request.cbk.seam.' .. head.Cbk)
			callback = cache.get('cbk.'..head.Cbk)
		end
		
		if callback then
			--记录回调错误状态
			if head.Opt == msgopts.haserror then
				--cache.set('ms.service.request.cbk.err.' .. head.Cbk,1)
				callback.err = 1
			end
			--记录回调结果
			--cache.set('ms.service.request.cbk.result.' .. head.Cbk,data or '')
			callback.result = data or ''
			--回调
			--callback:post(1)
			callback.seam:post(1)
		else
			console('the callback message can not find process function. --> callback id = ',head.Cbk)
		end
	else
		--获取处理方法
		--console('receive one message -> opt = ',head.Opt, ' channel = ', head.FromChannel, ' Command = ', head.Command, ' entid = ',tonumber(head.EntityId), ' enttype = ',head.EntityType)
		head.To = listener.id or 0
		local entity = entities.get(head.EntityId,head.EntityType)
		if not entity then
			console('the entity is not exist -> channel = ', head.FromChannel, ' entid = ',head.EntityId, ' enttype = ',head.EntityType, ' Command = ', head.Command)
			if head.Opt == msgopts.request then
				head.Opt = msgopts.haserror
				respond(listener,head,'this message can not process in service channel = ' .. (config.channel or 0) .. ' No.' .. listener.id .. ' Command = ' .. head.Command)
			end
		else
			entity:append_message({head = head,data = data})
		end
	end

end

return _M