--[[
tcp客户端
--]]
local meta = require 'core.tcp.meta'

local _M = {}
_M._VERSION = '0.01'

local mt = {__index = _M}

_M.new = function(self,host,port,timeout,async)
	--创建新的sock
	local sock, err = tcp()
	
    if not sock then
        return nil, err
    end
	--设置超时时间
	if timeout then
		sock:settimeout(timeout)
	end
	
	local service = {
		sock = sock,
		async = async,
		host = host,
		port = port,
	}
	
	return setmetatable(service,mt)
end

function _M:run(on_message,head,heart)
	if not self.sock or not self.host or not self.port then return false end
	--连接
	local ok, err = sock:connect(self.host, self.port)
    if not ok then
        return nil, "failed to connect: " .. err
    end

	self.head = head
	self.on_message = on_message
	self.heart = heart

	return meta.start(self,false)
end

function _M:send(content)	
	return meta.send(self,content)
end

function _M:close()
	meta.close(self)
end

return _M