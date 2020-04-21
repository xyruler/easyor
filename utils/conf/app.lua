--[[
本文件修改后，需重启服务才能生效
--]]
local console = core.log.info

local _M = {}

--初始化,服务启动时调用
--可选
_M.init = function()
	
	console('app init ...')
	
end

--阶段处理,开启了重载后生效
--可选
_M.phase = {}

_M.phase.preread = function()

end

_M.phase.rewrite = function()

end

_M.phase.access = function()

end

_M.phase.header_filter = function()

end

_M.phase.body_filter = function()

end

_M.phase.log = function()

end

--tcp,udp消息处理
--可选
_M.stream = {}

--tcp消息头结构 必需
--_M.stream.head = require '' 
_M.stream.head = {
	size = 8,
	get = function(data) --根据data生成head对象，head对象中必须包含size属性 
	end,
	attr_size_name = 'MessageSize' --head对象中size属性的属性名
}

_M.stream.heart = {	--激活心跳  可选
	interval = 5,	--心跳间隔
	data = ''		--心跳包数据
}

--有新连接进入
_M.stream.on_connect = function(client)
	
end

--消息处理 必需
_M.stream.on_message = function(client,head,data)

end

--连接断开 可选
_M.stream.on_close = function(client,close_reason)

end

return _M