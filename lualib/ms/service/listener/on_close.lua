--[[
与controller连接断开后的处理
--]]
local console = core.log.error
local cache = core.cache
local sleep = ngx.sleep

local interval = 5
if config and config.listener then
	interval = config.listener.retry_sleep or 5
end

local _M = function(listener,data,ty)
	--等待重连
	console('the connect closed')
	sleep(interval)
	console('reconnect-->')
	--重连
	while not listener:reconnect() do
		sleep(interval)
	end
	--重新注册
	console('register')
	local ok,rs = ms.service.register(listener)
	if ok then
		console('register listener success. --> listener.id = ',rs)
	else
		console('register to controller failed. --> ',rs)
		listener:close()
	end
end

return _M