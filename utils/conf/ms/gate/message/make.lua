--[[
将服务之间的消息转换为与客户端之间的消息
本文件修改后，需重启服务才能生效
--]]

--websocket --> 字节流格式版本
--[[
local Head = require 'data.message.head'

local _M = function(head,data)

	head.MessageSize = #data
	head.MessageCheck = Head.get_check(head)
	
	return Head.tostring(head) .. data
end

return _M
--]]

---[[
--websocket -> json格式版本
local cjson = core.cjson


local _M = function(head,data,status,extra)
	local msg = {}
	if head.Command then
		msg.model = head.EntityType
		msg.id = head.EntityId
		msg.type = head.Command
		msg.data = data
	else
		msg.status = status or 0
		msg.data = data
		msg.cbk = head.cbk
		msg.extra = head.extra
	end
	
	return cjson.encode(msg)
end

return _M
--]]

