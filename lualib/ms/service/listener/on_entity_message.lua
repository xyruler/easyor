--[[
消息处理
--]]
local msgopts = require 'ms.message.opts'
local respond = require 'ms.service.message.respond'
local listener = nil

local _M = function(entity,head,data)
	if not listener then
		listener = ms.service.listener
		if not listener then
			core.log.error('listener is nil')
		end
	end

	local fun = route.get('cmd_' .. head.ToChannel .. '_' .. head.Command)
	if fun then
		--处理消息
		local result,err = fun({
			entity = entity,
			head = head,
			data = data,
		})
		--如果是需要回复的消息，进行回复
		if head.Opt == msgopts.request then
			if result then
				head.Opt = msgopts.respond
				local ok,err = respond(listener,head,result)
				if not ok then
					head.Opt = msgopts.haserror
					respond(listener,head,err or 'process message failed.')
				end
			else
				head.Opt = msgopts.haserror
				respond(listener,head,err or 'process message failed.')
			end
		end
	else
		core.log.info('this message can not process in service channel = ' .. (config.channel or 0) .. ' No.' .. listener.id .. ' Command = ' .. head.Command)
		if head.Opt == msgopts.request then
			head.Opt = msgopts.haserror
			respond(listener,head,'this message can not process in service channel = ' .. (config.channel or 0) .. ' No.' .. listener.id .. ' Command = ' .. head.Command)
		end
	end
end

return _M