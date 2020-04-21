--[[
合并配置
--]]

local env = require 'utils.env'
local config = require 'utils.conf.default'

--检查必需的文件
local check_files = function()
	local files = {
		'config.lua',
		'app.lua',
	}
	
	for _,file in ipairs(files) do
		if not env.exist(env.workpath .. '/' .. file) then return false end
	end
	
	return true
end

local _M = function()
	--如果缺少必需的文件，则退出
	if not check_files() then return false end
	
	--项目中的config
	local cfg = require 'config'
	
	singleton_work = cfg.singleton_work		--是否是单例
	access_log_on = cfg.access_log_on		--是否开启访问日志
	loglevel = cfg.loglevel					--日志等级
	server_name = cfg.server_name			--服务名称
	
	stream_on = cfg.use_tcp or cfg.use_udp	--是否开启stream模块
	http_on = cfg.use_http					--是否开启http模块
	tcp_ports = cfg.use_tcp and cfg.tcp_ports or nil	--tcp监听端口
	udp_ports = cfg.use_udp and cfg.udp_ports or nil	--udp监听端口
	http_ports = cfg.use_http and cfg.http_ports or nil	--http监听端口
	http_allow_cross_domain = cfg.http_allow_cross_domain	--是否允许跨域访问
	
	config.phase = cfg.phase or {}	--流程控制开关
	
	if cfg.caches then	--缓存配置，需要在nginx config中配置share dicts
		local cache_num = 0
		config.share_dicts = config.share_dicts or {}
		for k,v in pairs(cfg.caches) do
			config.share_dicts[k] = v.share_dict_size
			cache_num = cache_num + 1
		end
		if cache_num > 0 then	--配置缓存同步使用的缓存
			config.share_dicts['sys_cache_miss'] = '10m'
			config.share_dicts['sys_cache_locks'] = '10m'
			config.share_dicts['sys_cache_ipc'] = '10m'
		end
	end
	
	if cfg.max_running_timers then	--计数器配置
		config.lua = config.lua or {}
		config.lua.lua_max_running_timers = cfg.max_running_timers
	end
	
	--运维配置
	--此处需改进，需根据不同的项目读取不同的运维配置
	--运维配置中直接修改全局变量
	require('ngxconf')

	if singleton_work then
		config.worker_num = 1
	else
		config.worker_num = cfg.worker_num
	end
	if loglevel then env.loglevel = loglevel end
	if not access_log_on then config.access_log = false end
	
	if not stream_on and not http_on then
		stream_on = true
		tcp_ports = nil
		udp_ports = nil
	end

	--将配置融合到最终配置中
	if stream_on then
		config.stream = {}
		config.stream.tcp = tcp_ports
		config.stream.udp = udp_ports
	end
	
	if http_on then
		config.http = {}
		config.http.server = {}
		config.http.server.listen = http_ports
		
		--http中主路由
		config.http.server.location_main = {}
		config.http.server.location_main.add_headers = {}
		if http_allow_cross_domain then
			table.insert(config.http.server.location_main.add_headers,"'Access-Control-Allow-Origin' '*'")
		end
		if http_allow_get then
			table.insert(config.http.server.location_main.add_headers,"'Access-Control-Allow-Methods' 'GET'")
		end
		if http_allow_post then
			table.insert(config.http.server.location_main.add_headers,"'Access-Control-Allow-Methods' 'POST'")
		end
		
		--静态文件访问
		if http_static_file_exts and #http_static_file_exts > 0 then
			config.http.server.location_file = {}
			config.http.server.location_file.exts = http_static_file_exts
			if http_static_file_root and #http_static_file_root > 0 then
				config.http.server.location_file.root = http_static_file_root
			end
			config.http.server.location_file.expires = http_static_file_expires or '7d'
			
			if http_static_file_allow_cross_domain then
				config.http.server.location_file.add_headers = {}
				config.http.server.location_file.add_headers[1] = "'Access-Control-Allow-Origin' '*'"
			end
		end
		
		--其它自定义路由
		config.http.server.locations = cfg.http_locations
	end
		
	return true
end

return _M