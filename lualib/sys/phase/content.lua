--[[
tcp模式下的content_by_lua
--]]
local ngx = ngx
local console = core.log.info

local tcpServer = require 'core.tcp.server'

local stream = app.stream or {}				--app中配置

local on_message = stream.on_message	--消息处理回调
local on_close = stream.on_close		--连接关闭后回调
local on_connect = stream.on_connect	--连接建立时回调

local head = stream.head				--消息头
--[[
head = {
	size = 11,					--消息头大小
	get = function(str) end, 	--消息头解析函数
	attr_size_name = '',		--消息头中表示消息体大小的属性字段名
}
--]]
if head then
	if not head.size or not head.get or not head.attr_size_name then
		head = false
	end
end
local heart = stream.heart				--心跳
if heart then
	--心跳中，心跳间隔和心跳包是必需的
	if not heart.interval or not heart.data then
		heart = nil
	end
end

local _on_connect = function()
	local sock,err = ngx.req.socket(true)

	if not sock then
		console('get sock failed.')
		return false
	end
	--创建服务
	local server = tcpServer:new(sock)
	
	if on_connect then
		on_connect(server)
	end
	--启动服务
	local ok,err = server:run(on_message,head,heart)
	
	if on_close then
		on_close(server,err)
	end
	return true
end

local _M = function()
	--检查各项参数
	if not on_message then
		console('there is not has on_message function')
		return 
	end
	
	if not head then
		console('wrong head struct')
		return
	end
	--创建连接
	local ok,err = pcall(_on_connect)
	if not ok then
		console('do on_connect error -> ',err)
	end
end

return _M