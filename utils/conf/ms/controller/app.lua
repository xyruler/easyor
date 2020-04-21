--[[
本文件修改后，需重启服务才能生效
--]]
local console = core.log.info
local go = core.go
local cache = core.cache
local ngx = ngx

local _M = {}

--打印消息流量
local log_message_num = function()
	local total_receive = 0
	local total_send = 0
	local btime = false
	while true do
		local first = cache.get('first')
		if not first then
			ngx.update_time()
			first = ngx.now()
			cache.set('first',first)
		end
		
		if not btime then btime = first end
		
		ngx.update_time()
		local endtime = ngx.now()
		local num_receive = cache.get('ms.controller.receive.count') or 0
		local num_send = cache.get('ms.controller.send.count') or 0
		total_receive = total_receive + num_receive
		total_send = total_send + num_send
		
		if num_receive > 0 or num_send > 0 then
			console('receive begin = ',first, '  end = ',endtime, ' num = ', num_receive, ' per = ', num_receive / (endtime - first), ' total = ', total_receive)
			console('send    begin = ',first, '  end = ',endtime, ' num = ', num_send, ' per = ', num_send / (endtime - first), ' total = ', total_send)
		end
		
		cache.set('first',endtime)
		cache.set('ms.controller.receive.count',0)
		cache.set('ms.controller.send.count',0)

		ngx.sleep(1)
	end
end

--初始化,服务启动时调用
_M.init = function()
	console('app init ...')
	
	--register route
	local ok = route.set('/connect',ms.controller.connect)
	
	if config.debug then
		go(1,log_message_num)
	end
	
end

return _M