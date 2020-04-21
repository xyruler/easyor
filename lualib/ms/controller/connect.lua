--[[
服务连接
--]]
local Websocket_Server = core.websocket.server
local respond = core.respond
local console = core.log.info
local cjson = core.cjson
local go = core.go
local cache = core.cache

--连接token
local token = 'KDFAPOSWKKWKEJKWPKFMMFSMLDKDIHRSJNSMNDAMDN'

local _M = function(args)
	if args.token ~= token then return respond(-1,{},'wrong params - token') end
	--创建服务
	local service = Websocket_Server:new()
	if not service then return respond(-1,{},'wrong connect mode') end
	--服务启动
	local on_message = ms.controller.service.on_message
	local on_close = ms.controller.service.on_close
	service:run(on_message,on_close,3)
	--给服务编号
	local snum = cache.get('controller.service.num') or 0
	snum = snum + 1
	service.number = snum
	cache.set('controller.service.num',snum)
	
	console('one service connected, no.', snum)
	cache.set('controller.service.no.' .. snum,service)
	
	return respond(0,{},'ok')
end

return _M