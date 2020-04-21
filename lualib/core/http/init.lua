--[[
http功能接口
--]]
local http = require "core.http.http"
local cjson = require "core.cjson"

--代理方式，弃用
local _M1 = function(url,args,method,body)
	local loc = '/proxy/' .. url
	local res = ngx.location.capture(loc,
		{
			method = method or ngx.HTTP_GET,
			args = args,
			body = body
		}
	)
	if 200 ~= res.status then
		return false,"http errror code " .. res.status
	end
	
	return true,res.body
end

local request = function(url,args,headers,body,verify,method)
	local httpc = http.new()
	local rs,err = httpc:request_uri(url,{
		method = method or "GET",
		query = args,
		body = body,
		headers = headers,
		ssl_verify = verify or false,
	})
	httpc:set_keepalive(60)
	
	if not rs then return false,err end
	if 200 ~= rs.status then
		return false,"http errror code " .. rs.status .. rs.body or ''
	end
	
	return true,rs.body,rs.headers
end

local _M = {}

_M.get = function(url,args,headers,verify)
	return request(url,args,headers,nil,verify,nil)
end

_M.post = function(url,args,body,headers,verify)
	if type(body) == 'table' then body = cjson.encode(body) end
	return request(url,args,headers,body,verify,'POST')
end

return _M