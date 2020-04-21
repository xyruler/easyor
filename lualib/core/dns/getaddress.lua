--[[
根据url获取ip
使用linux系统中配置的dns
--]]
local io_open = io.open
local ngx_re_gmatch = ngx.re.gmatch

local _dns_servers = false

local _read_file_data = function(path)
    local f, err = io_open(path, 'r')

    if not f or err then
        return nil, err
    end

    local data = f:read('*all')
    f:close()
    return data, nil
end

local _read_dns_servers_from_resolv_file = function()
    local text = _read_file_data('/etc/resolv.conf')
	if not text then return false end
    local captures, it, err
    it, err = ngx_re_gmatch(text, [[^nameserver\s+(\d+?\.\d+?\.\d+?\.\d+$)]], "jomi")

    for captures, err in it do
        if not err then
			if not _dns_servers then _dns_servers = {} end
            _dns_servers[#_dns_servers + 1] = captures[1]
        end
    end
end

local ngx_re_find = ngx.re.find
local resolver = require "resty.dns.resolver"
local cache = require 'core.innercache'

local _is_addr = function(hostname)
    return ngx_re_find(hostname, [[\d+?\.\d+?\.\d+?\.\d+$]], "jo")
end

local _get_addr = function(hostname)
    if _is_addr(hostname) then
        return hostname, hostname
    end

    local addr = cache.get(hostname)

    if addr then
        return addr, hostname
    end

	if not _dns_servers then _read_dns_servers_from_resolv_file() end
	
    local r, err = resolver:new({
        nameservers = _dns_servers,
        retrans = 5,  -- 5 retransmissions on receive timeout
        timeout = 2000,  -- 2 sec
    })

    if not r then
        return hostname, hostname
    end

    local answers, err = r:query(hostname, {qtype = r.TYPE_A})

    if not answers or answers.errcode then
        return hostname, hostname
    end

    for i, ans in ipairs(answers) do
        if ans.address then
            cache.set(hostname, ans.address, 300)
            return ans.address, hostname
        end
    end

    return hostname, hostname
end

return _get_addr