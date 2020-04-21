--[[
websocket客户端
--]]
local meta = require 'core.websocket.meta'
local Client = require "resty.websocket.client"
local semaphore = require "ngx.semaphore"

local _M = {}

local mt = { __index = meta }

function _M:new(host,timeout,max_len,async)
	if not host then
		return false,'no host'
	end
	return setmetatable({
        msg = {},
		heart = false,
		host = host,
		timeout = timeout,
		max_payload_len = max_len,
		sema = semaphore:new(),
		async = async,
    }, mt)
end

return _M