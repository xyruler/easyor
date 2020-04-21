--[[
请求数据
--]]
local config = config
local cache = core.cache
local ffi = core.ffi
local cjson = core.cjson
local tonumber = tonumber

local semaphore = require "ngx.semaphore"
local msghead = require 'ms.message.head'
local msgopts = require 'ms.message.opts'
local opt_request = msgopts.request

if not cache.get('ms.service.request.cbk') then
	cache.set('ms.service.request.cbk',0)
end

local wait_time = config.request_timeout or 5

local clear_cache = function(cbk)
	cache.del('ms.service.request.cbk.seam.' .. cbk)
	cache.del('ms.service.request.cbk.result.' .. cbk)
	cache.del('ms.service.request.cbk.err.' .. cbk)
end

local listener = nil

local _M = function(channel,command,data,entityid,entitytype,opt,to)
	--检查与controller的连接
	if not listener then
		listener = ms.service.listener
		if not listener then
			return false,'no listener'
		end
	end
	--检查参数
	if not channel or not command or not data then
		return false,'wrong params'
	end
	--获取回调编号
	local cbk = cache.get('ms.service.request.cbk') + 1
	--组装消息对象
	local head,size = msghead.get()
	head.Opt = opt or opt_request		--默认为请求
	head.ToChannel = tonumber(channel)	--消息频道
	head.Command = tonumber(command)	--消息号
	head.To = to or 0					--目标服务编号，0表示不指定
	head.FromChannel = config.channel	--发起服务频道
	head.From = listener.id or 0		--发起服务编号
	head.Cbk = cbk						--回调编号broadcast and 0 or 
	head.EntityId = tonumber(entityid) or 0		--数据对象id
	head.EntityType = entitytype or 0	--数据对象类型
	
	--发送消息
	if type(data) == 'table' then
		data = cjson.encode(data)
	end
	local msg = ffi.string(head,size) .. data
	listener:send(msg)
	
	if head.Opt ~= opt_request then return true end
	
	--记录回调对象
	local seam = semaphore:new()
	cache.set('ms.service.request.cbk',cbk)
	--cache.set('ms.service.request.cbk.seam.' .. cbk,seam)
	cache.set('cbk.' .. cbk,{seam = seam})
	--等待回复
	seam:wait(wait_time)
	
	--获取回复数据
	local ccc = cache.get('cbk.'..cbk)
	local err = ccc.err
	local result = ccc.result
	--local err = cache.get('ms.service.request.cbk.err.' .. cbk)
	--local result = cache.get('ms.service.request.cbk.result.' .. cbk)
	
	if err then
		clear_cache(cbk)
		return false,result
	end
	
	if not result then
		clear_cache(cbk)
		return false,'time out'
	end
	--清除请求相关的缓存
	clear_cache(cbk)
	return true,result
end

return _M
