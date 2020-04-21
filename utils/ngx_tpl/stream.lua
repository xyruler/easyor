--[[
nginx config stream配置
--]]

local env = require 'utils.env'
local template = require 'lualib.resty.template'

local _M = {}

--[[upstream
    {* config.lua and config.lua.lua_socket_log_errors and 'lua_socket_log_errors ' .. config.lua.lua_socket_log_errors .. ';' or '' *}

	{% for name,data in pairs(config.upstream or {}) do %}
    upstream  {* name *}  { 
	{% for _,value in ipairs(data.servers) do %}
        server    {* value *};
	{% end %}
	{* data.mode and data.mode .. ';' or '' *}
	{% if data.balancer_by_lua_file then %}
        balancer_by_lua_block {
	    local balancer = require "{* data.balancer_by_lua_file *}"
            if type(balancer) == 'function' then
                balancer()
            end
        }
	{% end %}
	{* data.keepalive and 'keepalive ' .. data.keepalive .. ';' or '' *}
    }
	{% end %}
--]]

local tpl = [==[
stream {
    lua_package_path "{* env.workpath *}/?.lua;{* env.workpath *}/?/init.lua;{* env.myorlualib *}/?.lua;{* env.myorlualib *}/?/init.lua;{* env.orlualib *}/?.lua";
    lua_package_cpath "{* env.workpath *}/?.so;{* env.myorlualib *}/?.so;{* env.orlualib *}/?.so";
	
    {% for name,size in pairs(config.share_dicts or {}) do %}
    lua_shared_dict {* name *} {* size *};
    {% end %}

    init_by_lua_block {
        require "sys.core"
        sys.phase.init()
    }

    init_worker_by_lua_block {
        sys.phase.init_worker()
    }
	
	{% if config.phase and config.phase.preread then %}
    preread_by_lua_block {
        sys.phase.preread()
    }
	{% end %}
	
	{% if config.phase and config.phase.log then %}
    log_by_lua_block {
        sys.phase.log()
    }
	{% end %}
	
    server {
        {% for _, port in ipairs(config.stream.tcp or {}) do %}
        listen {*port*};
        {% end %}
        {% for _, port in ipairs(config.stream.udp or {}) do %}
        listen {*port*} udp;
        {% end %}

        content_by_lua_block {
            sys.phase.content()
        }
    }
}

]==]

_M.make = function(config)
	return template.compile(tpl)({
		config = config,
		env = env
	})
end

return _M
