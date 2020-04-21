--[[
http模式下的统一回复
--]]

local _M = function(status,data,msg)
	local rs = {}
	rs.status = status
	rs.msg = msg
	rs.data = data
	return rs
end

return _M