--[[
服务连接
--]]
local s_sub = string.sub

local Websocket_Server = core.websocket.server
local respond = core.respond

local stream = app.stream
local msgparse = require 'data.message.parse'

local on_message = function(service,msg,ty)
	local head,data = msgparse(msg)
	return stream.on_message(service,head,data)
end

--连接token
local _M = function(args)
	if not stream or not stream.on_connect or not stream.on_message or not stream.on_close then return respond(-1,{},'wrong stream') end
	--创建服务
	local service = Websocket_Server:new()
	if not service then return respond(-1,{},'wrong connect mode') end
	
	local ok,err = stream.on_connect(service,args)
	if ok then
		--服务启动
		service:run(on_message,stream.on_close,3)
		return respond(0,{},'ok')
	else
		return respond(-1,{},err)
	end
end

return _M