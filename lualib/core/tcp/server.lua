--[[
tcp服务端
--]]
local meta = require 'core.tcp.meta'

local _M = {}
_M._VERSION = '0.01'

local mt = {__index = _M}

_M.new = function(self,sock,timeout,async)
	if not sock then return false end
	
	if timeout then
		sock:settimeout(timeout)
	end
	
	local service = {
		sock = sock,
		async = async,
	}
	
	return setmetatable(service,mt)
end

function _M:run(on_message,head,heart)
	if not on_message then return false end
	self.head = head
	self.on_message = on_message
	self.heart = heart

	return meta.start(self,true)
end

function _M:send(content)	
	return meta.send(self,content)
end

function _M:close()
	meta.close(self)
end

return _M