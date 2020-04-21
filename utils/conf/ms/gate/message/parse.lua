--[[
websocket模式下与客户端之间的消息解析
本文件修改后，需重启服务才能生效
返回的结果由app.stream.on_message接收
--]]

--websocket --> 字节流格式版本
--[[
local Head = require 'data.message.head'

local _M = function(msg)
	local head = Head.get(data)
	data = s_sub(data,Head.size)
	
	return head,data
end

return _M
--]]


---[[
--websocket -> json格式版本
local config = config
local cjson = core.cjson

local _M = function(msg)
	local data = cjson.decode(msg)
	if not data or type(data) ~= 'table' or not data.cmd or not data.data or not data.cbk then return false,false end
	return true,data
end

return _M
--]]