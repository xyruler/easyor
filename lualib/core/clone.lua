--[[
深度复制
--]]
local _M = false

_M = function(data)
	local copy = data
	if type(data) == 'table' then
		copy = {}
		for i,v in pairs(data) do
			copy[i] = _M(v)
		end
	end
	return copy
end

return _M