--[[
重载脚本
--]]
local require = require

local _M = function(script)
	package.loaded[script] = nil
	return require(script)
end

return _M