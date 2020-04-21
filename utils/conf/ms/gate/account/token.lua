--[[
获取登录token
--]]
local math_random = math.random
local math_randomseed = math.randomseed

local t_concat = table.concat
local senssion = cache.senssion --db.senssion

math_randomseed(ngx.now())
local strs = {'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','1','2','3','4','5','6','7','8','9','0'}
local strs_num = #strs

local _new_token = function()
	local token = {}
	
	for i = 1,32 do
		token[i] = strs[math_random(1,strs_num)]
	end
	
	return t_concat(token)
end

local _M = function(uid,bnew)
	local token = ''
	if bnew then
		token = _new_token()
		senssion:set('zxc.gate.uid.' .. uid,token)
	else
		token = senssion:get('zxc.gate.uid.' .. uid)
	end
	return token
end

return _M
