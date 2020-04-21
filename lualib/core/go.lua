--[[
定时器
--]]
local timer = ngx.timer.at

local _M = function(delay,fun,...)
	local callfun = function(premature,...)
		if premature then return end
		fun(...)
	end
	return timer(delay,callfun,...)
end

return _M