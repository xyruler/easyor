--[[
与服务间的消息通讯
--]]
local ffi = core.ffi
local console = core.log.info 
local cache = core.cache
local config = config

local manager = require 'ms.controller.manager'
local commands = require 'ms.controller.commands'

local receive = require 'ms.message.receive'
local msghead = require 'ms.message.head'
local msgopts = require 'ms.message.opts'

--controller频道默认为0
local mychannel = config.controller or 0

--回复错误
local respond_error = function(service,head,msg)
	head.Opt = msgopts.haserror
	return service:send(ffi.string(head,msghead.size) .. msg)
end

--回复消息
local respond = function(service,head,msg)
	head.Opt = msgopts.respond
	return service:send(ffi.string(head,msghead.size) .. msg)
end

local _M = function(service,msg)
	cache.set('ms.controller.receive.count',(cache.get('ms.controller.receive.count') or 0) + 1)
	--解析消息
	local head,data,err = receive(msg)
	if not head or not msg then
		console('receive one wrong message from service No.',service.number,' --> err = ', err)
		return false,'wrong data' .. err
	end

	if head.ToChannel == mychannel then
		local docmd = commands[head.Command]
		if docmd then
			local ok,rs = docmd(service,head,data)
			if ok then
				respond(service,head,rs or 1)
			else
				respond_error(service,head,rs or 'unknown')
			end
		else
			respond_error(service,head,'the message can not process.')
		end
	else
		if not service.sid then
			--服务未准备，直接关闭
			service:close(1111)
			console('the service is not register. no.',service.number)
			return false,'the service wrong'
		end
		
		local ok = false
		local err = ''
		if head.Opt == msgopts.broadcast then
			--广播消息
			ok,err = manager.broadcast(head.ToChannel,head.Command,msg,head.EntityId,head.EntityType)
			--console('receive one broadcast message -> ',head.ToChannel, '-' ,head.Command,' => ', head.EntityId,' - ',head.EntityType,' broadcast num = ',ok,' err = ',err)
		elseif head.Opt == msgopts.request or head.Opt == msgopts.pushtogate then
			--请求消息,推送消息
			ok,err = manager.transfer(head.ToChannel,head.To,msg,head.EntityId,head.EntityType,true)
			--console('receive one transfer message -> ',head.ToChannel, '-' ,head.To, '-' ,head.Command,' => ', head.EntityId,' - ',head.EntityType,' transfer num = ',ok,' err = ',err)
		elseif head.Opt == msgopts.respond or head.Opt == msgopts.haserror then
			--回复消息
			ok,err = manager.transfer(head.FromChannel,head.From,msg,head.EntityId,head.EntityType)
		end
		
		if not ok then
			respond_error(service,head,err)
		end
	end
end

return _M