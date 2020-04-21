--[[
生成nginx config
--]]
local env = require 'utils.env'
local head = require 'utils.ngx_tpl.head'
local stream = require 'utils.ngx_tpl.stream'
local http = require 'utils.ngx_tpl.http'

local _M = {}

_M.make = function(config)
	local tp_head = head.make(config)
	local tp_stream = config.stream and stream.make(config) or ''
	local tp_http = config.http and http.make(config) or ''
	
	return tp_head .. tp_stream .. tp_http
end

return _M
