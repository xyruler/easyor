--[[
nginx config 头部配置
--]]

local env = require 'utils.env'
local template = require 'lualib.resty.template'

local _M = {}

local tpl = [==[
master_process on;
{% if config.user then %}
user {* config.user *};
{% end %}

worker_processes {* config.worker_num or env.cpunum or 'auto' *};
{% if env.os_name == "Linux" then %}
worker_cpu_affinity {* config.worker_cpu_affinity or 'auto' *};
{% end %}

error_log {* env.logpath *}/error_{* env.project *}.log {* env.loglevel *};
pid {* env.logpath *}/nginx_{* env.project *}.pid;

worker_rlimit_nofile {* config.worker_rlimit_nofile or env.ulimit or 65535 *};

events {
    {% if config.accept_mutex then %}
    accept_mutex on;
	{% end %}
    use {* config.eventtype or 'epoll' *};
    worker_connections {* config.worker_connections or env.ulimit or 20480 *};
    {% if config.multi_accept then %}
    multi_accept on;
	{% end %}
}

 {% if config.open_core then %}
worker_rlimit_core  {* config.open_core *};
working_directory {* env.workpath *};
{% end %}
 {% if config.worker_shutdown_timeout then %}
#worker_shutdown_timeout {* config.worker_shutdown_timeout *};
{% end %}
]==]

_M.make = function(config)
	return template.compile(tpl)({
		config = config,
		env = env
	})
end

return _M

