--[[
日志
--]]
local ngx_log  = ngx.log

local _M = {version = 0.1}
local cmds = {
	stderr = ngx.STDERR,
	emerg  = ngx.EMERG,
	alert  = ngx.ALERT,
	crit   = ngx.CRIT,
	error  = ngx.ERR,
	warn   = ngx.WARN,
	notice = ngx.NOTICE,
	info   = ngx.INFO, 
}

for name, log_level in pairs(cmds) do
    _M[name] = function(...)
        return ngx_log(log_level, ...)
    end
end

return _M
