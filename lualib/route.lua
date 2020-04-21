--[[
路由管理
仅支持全匹配模式
--]]
local config = config
local route = {}
local default_api = nil
local api_root = config.route_root or 'api'
local s_lower = string.lower

local console = core.log.info

local _M = {}

--获取路由
_M.get = function(path)
	path = s_lower(path)
	if route[path] then 
		return route[path]
	end
    local ok, api = pcall(core.reload, api_root .. "/" .. path)
	if not ok or type(api) ~= "function" then
		return default_api
	end
	if not config.debug then
		route[path] = api
	end
	return api
end

--设置路由
_M.set = function(path,api)
	if not path or not api then
		return false
	end
	
	if type(api) == 'string' then
		local ok, fun = pcall(require, api)
		if ok then
			api = fun
		else
			core.log.error(fun)
		end
	end
	
	if type(api) ~= 'function' then
		core.log.error('get api function error-> path = ',path)
		return false
	end
	
	path = s_lower(path)
	route[path] = api
	
	return true
end

--设置默认的路由
_M.set_default = function(default)
	if type(default) == 'string' then
		local ok, fun = pcall(require, default)
		if ok then
			default = fun
		else
			core.log.error('set default route api error -> ' ,fun or 'unkonwn error')
		end
	end
	
	if type(default) == 'function' then
		default_api = default
	end
end

return _M