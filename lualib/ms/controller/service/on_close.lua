--[[
服务掉线时处理
--]]
local console = core.log.error
local cache = core.cache
local manager = require 'ms.controller.manager'

local _M = function(service,data,ty)
	manager.remove(service)
	console('the service No.' .. service.number .. ' closed cid = ',service.cid , ' sid = ',service.sid, ' plusmsg -> ',#service.msg)
	cache.del('controller.service.no.' .. service.number)
end

return _M