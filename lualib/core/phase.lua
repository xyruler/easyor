--[[
阶段处理方法集合
--]]
local _M = {version = 0.1}

local phases = {
	'init',
	'init_worker',
	'ssl_certificate',
	'preread',
	'rewrite',
	'access',
	'content',
	'route',
	'balancer',
	'header_filter',
	'body_filter',
	'log',
	'ssl_session_fetch',
	'ssl_session_store',
}

for phase in ipairs(phases) do
	_M[phase] = function(dofun)
		sys.phase[phase] = dofun
	end
end

return _M