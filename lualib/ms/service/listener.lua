--[[
创建与controller的连接
--]]
local cache = core.cache
local config = config
local console = core.log.info
local WebClient = core.websocket.client

local token = 'KDFAPOSWKKWKEJKWPKFMMFSMLDKDIHRSJNSMNDAMDN'

local on_message = require 'ms.service.listener.on_message'
local on_close = require 'ms.service.listener.on_close'

local listener = nil

local sleep = ngx.sleep

local interval = 5
if config and config.listener then
	interval = config.listener.retry_sleep or 5
end

local connect = function()
	local ok,err = listener:run(on_message,on_close,3)
	if not ok then
		console('connect to controller failed. err -> ',err)
		return false
	end

	return true
end 

local _M = function()
	if listener then return listener end

	if config.listener and config.listener.host then
		local host = 'ws://' .. config.listener.host .. '/connect?token=' .. token
		local timeout = config.listener.timeout
		local max_len = config.listener.max_len
		
		listener = WebClient:new(host,timeout,max_len,false)
	else
		console('create listener failed --> config error')
	end

	if not listener then return nil end
	
	while not connect() do
		sleep(interval)
	end
	
	return listener
end

return _M