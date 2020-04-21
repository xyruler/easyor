local account = cache.account
local now = ngx.now
local consloe = core.log.info
local cjson = core.cjson
local md5 = ngx.md5
local clone = core.clone

local _M = function(args)
	if not args.account then return false,'wrong account info' end
	
	local bnew = false
	local acc = account:get(args.account)
	if not acc then
		bnew = true
		acc = {}
		acc.account = args.account or ''
		acc.password = md5(args.password or '')
		acc.status = acc.status or 1
		acc.regtime = acc.regtime or now()
		
		local nk,err = account:set(args.account,acc)
		if not nk then
			return false,'create new acc failed.--> ' .. err
		end
	else
		if acc.password ~= md5(args.password) then
			return false,'wrong password'
		end
		if acc.status ~= 1 then
			return false,'wrong the account status'
		end
	end
	
	return clone(acc),bnew and 1 or 0
end

return _M