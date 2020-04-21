--[[
内部消息解析
--]]
local s_sub = string.sub

local config = config
local msghead = require 'ms.message.head'

local _M = function(data)
	if not data then return nil,nil,'wrong data' end
	local head,size = msghead.get(data)
	if not head then return nil,nil,size end
	
	return head,s_sub(data,size + 1)
end

return _M
