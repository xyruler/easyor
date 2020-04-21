local respond = core.respond
local cjson = core.cjson
local get_account = require 'data.account.find'
local get_token = require 'data.account.token'
local del_client = require 'ms.gate.client.del'

local _M = function(args)
	if not args or not args.entity or not args.entity.client then return respond(-1,{},'wrong entity') end
	local oldclient = args.entity.client
	if oldclient then
		del_client(oldclient,true)
		oldclient.login_in_other_service = true
		local msg = {
			model = 100,
			type = 105,
			id = 4000,
			data = 'the user login from other device'
		}
		
		oldclient:send(cjson.encode(msg))
		
		oldclient:close(4000,'the user login from other device')
	end
	
	return respond(0,{},'ok')
end

return _M

