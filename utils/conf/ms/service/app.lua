--[[
本文件修改后，需重启服务才能生效
--]]
local console = core.log.info
local go = core.go
local route = route
local start_service = require 'ms.service.start'

local listen = require 'ms.service.message.listen'
local regcmd = require 'ms.service.message.regcommand'

local _M = {}
--初始化,服务启动时调用

_M.init = function()
	console('app init ...')
	
	--register listen commands
	--listen(channel,command,api)
	
	--register myself commands
	--regcmd(command,api)
	
	--create service
	core.go(1,start_service)
end

return _M