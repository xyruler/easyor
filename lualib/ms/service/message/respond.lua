--[[
获取回复消息体
--]]
local ffi = core.ffi
local config = config
local cjson = core.cjson
local msghead = require 'ms.message.head'

local _M = function(listener,head,data)
	local ty = type(data)
	if ty ~= 'string' then
		if ty == 'table' then
			data = cjson.encode(data)
		else
			data = tostring(data)
		end
	end
	if not data then
		return false,'wrong data'
	end
	return listener:send(ffi.string(head,msghead.size) .. data)
end

return _M
