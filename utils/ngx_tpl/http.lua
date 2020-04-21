--[[
nginx config http部分配置
--]]


local env = require 'utils.env'
local template = require 'lualib.resty.template'

local _M = {}

--[[
	不考虑https
		
		{% if config.ssl then %}
        ssl    on;
		{% for name,value in pairs(config.ssl or {}) do %}
        {* name *}   {* value *};
		{% end %}
        ssl_certificate_by_lua_block {
            sys.phase.ssl_certificate()
        }
		{% end %}


--]]

local tpl = [==[
http {
    lua_package_path "{* env.workpath *}/?.lua;{* env.workpath *}/?/init.lua;{* env.myorlualib *}/?.lua;{* env.myorlualib *}/?/init.lua;{* env.orlualib *}/?.lua";
    lua_package_cpath "{* env.workpath *}/?.so;{* env.myorlualib *}/?.so;{* env.orlualib *}/?.so";

	{% for name,size in pairs(config.share_dicts or {}) do %}
    lua_shared_dict {* name *} {* size *};
	{% end %}

    include       mime.types;
    #default_type  application/octet-stream;
    
    {% for name,format in pairs(config.logformat or {}) do %}
    log_format {* name *} {* format *}
    {% end %}
    {% if config.access_log then %}
    access_log  {* env.logpath *}/access_{* env.project *}.log  {* config.access_log.format or '' *}  {* config.access_log.buffer and 'buffer='..config.access_log.buffer or '' *};
    {% end %}
	
	{% for name,value in pairs(config.trans or {}) do %}
    {* name *}   {* value *};
	{% end %}
	{% for name,value in pairs(config.lua or {}) do %}
    {* name *}   {* value *};
	{% end %}
	{% for name,time in pairs(config.timeout or {}) do %}
    {* name *}   {* time *};
	{% end %}
	{% for name,value in pairs(config.client_buffer or {}) do %}
    {* name *}   {* value *};
	{% end %}
	
	{% for name,value in pairs(config.fastcgi or {}) do %}
    {* name *}   {* value *};
	{% end %}
	{% if config.gzip then %}
    gzip    on;
	{% for name,value in pairs(config.gzip) do %}
    {* name *}   {* value *};
	{% end %}
	{% end %}
	
	{% if config.resolver then %}
    resolver {% for _, dns_addr in ipairs(config.resolver.list or {}) do %} {*dns_addr*} {% end %} {* config.resolver.ipv6 and '' or 'ipv6=off' *};
    resolver_timeout 5;
	{% end %}
	{% for name,value in pairs(config.proxy or {}) do %}
    {* name *}   {* value *};
	{% end %}
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
	{% if config.http.server then %}
	
    init_by_lua_block {
        require "sys.core"
        sys.phase.init()
    }

    init_worker_by_lua_block {
        sys.phase.init_worker()
    }
	{% if config.phase and config.phase.ssl_session_fetch then %}
    ssl_session_fetch_by_lua_block {
        sys.phase.ssl_session_fetch()
    }
	{% end %}
	
	{% if config.phase and config.phase.ssl_session_store then %}
    ssl_session_store_by_lua_block {
        sys.phase.ssl_session_store()
    }
	{% end %}
	
	{% if config.phase and config.phase.rewrite then %}
    rewrite_by_lua_block {
        sys.phase.rewrite()
    }
	{% end %}
	
	{% if config.phase and config.phase.access then %}
    access_by_lua_block {
        sys.phase.access()
    }
	{% end %}
	
	{% if config.phase and config.phase.header_filter then %}
    header_filter_by_lua_block {
        sys.phase.header_filter()
    }
	{% end %}
	
	{% if config.phase and config.phase.body_filter then %}
    body_filter_by_lua_block {
        sys.phase.body_filter()
    }
	{% end %}
	
	{% if config.phase and config.phase.log then %}
    log_by_lua_block {
        sys.phase.log()
    }
	{% end %}
	
    server {
		{% for _,port in ipairs(config.http.server.listen or {'80'}) do %}
        listen {* port *};
		{% end %}
        {* config.http.server.server_name and 'server_name ' .. config.http.server.server_name .. ';' or '' *}
        root {* env.workpath *};
        charset utf-8;
        error_page   500 502 503 504  /50x.html;
		
        location = /50x.html {
            root   html;
        }
		
		{% if config.http.server.location_file then %}
        location ~ .*\.({* config.http.server.location_file.exts or 'gif|jpg|jpeg|bmp|png|ico|txt|js|css|html|htm' *})$ {
            {* config.http.server.location_file.root and 'root ' .. config.http.server.location_file.root .. ';' or '' *}
            {* config.http.server.location_file.expires and 'expires ' .. config.http.server.location_file.expires .. ';' or '' *}
			
            {% if config.http.server.location_file.allow then %}
			{% for _,ip in ipairs(config.http.server.location_file.allow or {}) do %}
            allow {* ip *};
			{% end %}
            deny    all;
			{% end %}
			{% for _,header in ipairs(config.http.server.location_file.add_headers or {}) do %}
            add_header {* header *};
			{% end %}
        }
		{% end %}
		
		{% for _,info in pairs(config.http.server.locations or {}) do %}
		{% if info.path then %}
        location {* info.mode or '=' *} {* info.path *} {
            {% if info.allow then %}
			{% for _,ip in ipairs(info.allow or {}) do %}
            allow {* ip *};
			{% end %}
            deny    all;
			{% end %}
			
			{% for _,header in ipairs(info.add_headers or {}) do %}
            add_header {* header *};
			{% end %}
			
            set $api_path "{* info.real_path or info.path *}";
            content_by_lua_block {
				ngx.say(sys.phase.route())
			}
        }
		{% end %}
		{% end %}
		
		{% if config.http.server.location_main then %}
        location / {
            {% if config.http.server.location_main.allow then %}
			{% for _,ip in ipairs(config.http.server.location_main.allow or {}) do %}
            allow {* ip *};
			{% end %}
            deny    all;
			{% end %}
			
			{% for _,header in ipairs(config.http.server.location_main.add_headers or {}) do %}
            add_header {* header *};
			{% end %}
            content_by_lua_block {
                ngx.say(sys.phase.route())
            }
        }
		{% end %}
    }
	{% end %}
	
	{% if config.http.mustusehttps then %}
    server {
        listen      80;
        {* config.http.server.server_name and 'server_name ' .. config.http.server.server_name .. ';' or '' *}
        # rewrite  ^   https://$server_name$request_uri? permanent;
        return 301 https://$server_name$request_uri;
    }
	{% end %}
}
]==]

_M.make = function(config)
	return template.compile(tpl)({
		config = config,
		env = env
	})
end

return _M
