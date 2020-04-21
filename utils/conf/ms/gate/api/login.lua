local respond = core.respond
local get_account = require 'data.account.find'
local get_token = require 'data.account.token'

local _M = function(args)
	if not args or not args.account then return respond(-1,{},'wrong params.') end
	
	local acc,bnew = get_account(args)
	if not acc then return respond(-1,{},bnew) end
	
	acc.password = nil
	acc.token = get_token(acc.uid,true)
	return respond(0,{acc = acc,bnew = bnew},'ok')
end

return _M

