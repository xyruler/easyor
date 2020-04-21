--[[
默认处理
--]]
local make_client_message = require 'data.message.make'

local _M = function(args)
	--core.log.info('on message default')
	if not args or not args.entity or not args.entity.client then return false,'no entity client' end
	local msg = make_client_message(args.head,args.data)
	args.entity.client:send(msg)

end

return _M