--[[
服务注册
--]]
local cjson = core.cjson
local manager = require 'ms.controller.manager'

local _M = function(service,head,data)
	local args = cjson.decode(data)
	if not args then 
		return false,'the service register failed. wrong pramas'
	end

	service.cid = args.cid and tonumber(args.cid) or nil
	
	if type(args.listen) == 'table' then
		service.listen = args.listen
	end

	local ok = manager.add(service)
	if not ok then
		service:close(1112)
		console('the service register failed. no.',service.number)
		return false,'the service register failed. no.'..service.number
	end
	
	return true
end

return _M
