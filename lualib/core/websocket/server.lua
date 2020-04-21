--[[
websocket服务端
--]]
local meta = require 'core.websocket.meta'
local Server = require "resty.websocket.server"
local semaphore = require "ngx.semaphore"

local _M = {}
_M._VERSION = '0.01'

local mt = { __index = meta }

function _M:new(timeout,max_len,async)
	local service = {
        msg = {},
		heart = false,
		timeout = timeout,
		max_payload_len = max_len,
		conn = Server:new{
			timeout = timeout or 0,
			max_payload_len = max_len or 65535,
		},
		sema = semaphore:new(),
 		async = async,
   }
	if not service.conn then return false end
	
	return setmetatable(service, mt)
end

return _M