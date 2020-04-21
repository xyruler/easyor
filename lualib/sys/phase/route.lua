--[[
http模式下的content_by_lua
--]]
local cjson = core.cjson
local respond = core.respond
local console = core.log.info
local config = config
local route = route

local require = require

local _M = function(api_path,args)
	local rs = false
	--整理参数
	api_path = api_path or ngx.var.api_path or ngx.var.uri
	args = args or ngx.req.get_uri_args()
    console(api_path,'-->',cjson.encode(args))
	--如果无路由，返回默认结果
	if #api_path <= 1 then return 'welcome to us' end
	--获取路由
	local api = route.get(api_path)
    if not api then
		rs = 'invalid request'
	else
		--如果是post方法，获取post参数
		args = args or {}
		if ngx.req.get_method() == "POST" then
			if not config.no_need_read_post or not config.no_need_read_post[api_path] then
				ngx.req.read_body()
				local args_post = ngx.req.get_post_args()
				if args_post then
					for k, v in pairs(args_post) do
						args[k] = v
					end
				end
			end
		end
		--执行
		local ok
		ok, rs = pcall(api, args)
		if not ok then
			console("call function err --> ",rs)
			if config.debug then
				rs = respond(-3, {}, rs)
			else
				rs = respond(-3, {}, 'call api failed')
			end
		end
    end
	--返回结果
	local ty = type(rs)
	if ty == "table" then
		rs = cjson.encode(rs)
	else
		if rs then rs = tostring(rs) end
	end
    return rs
end

return _M