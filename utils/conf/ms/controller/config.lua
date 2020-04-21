--[[
本文件修改后，需重启服务才能生效
本模块中，不能直接执行require语句
--]]

local _M = {}
_M.debug = true		--调试状态，生产时请设置为false

-------------------------
--服务配置
--是否为单一进程服务
_M.singleton_work = true
--日志等级
_M.loglevel = 'info'
--是否开启access日志
_M.access_log_on = true

--服务使用的协议
_M.use_http  = true
--端口设置
_M.http_ports = {8800}
--是否允许跨域
_M.http_allow_cross_domain = true

--频道定义
_M.channels = {
	controller = 0,
	gate = 1,
	logic = 2,
}

return _M