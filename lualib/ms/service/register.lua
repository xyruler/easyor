--[[
服务注册
--]]
local tonumber = tonumber
local cjson = core.cjson

local _M = function(listener)
	local args = {}
	args.cid = config.channel
	args.listen = config.listen_list or {}
	
	local request = ms.service.message.request
	local ok,rs = request(0,1,cjson.encode(args))
	if ok then
		rs = tonumber(rs)
		listener.id = rs
	end
	return ok,rs
end

return _M
