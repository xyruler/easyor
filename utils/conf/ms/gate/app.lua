--[[
本文件修改后，需重启服务才能生效
--]]
local console = core.log.info

local go = core.go
local route = route
local cjson = core.cjson
local config = config
local respond = core.respond
local cache = core.cache

local start_service = require 'ms.service.start'
local listen = require 'ms.service.message.listen'
local regcmd = require 'ms.service.message.regcommand'

local _M = {}

--初始化,服务启动时调用
_M.init = function()
	console('app init ...')
	
	--websocket服务url
	route.set('/connect','ms.gate.on_connect')
	--默认处理
	route.set_default('ms.gate.on_message_default')
	
	--挤号
	listen(config.channels.controller,2,'api.login_in_other_service')
	
	--create service
	core.go(1,start_service)
end

--消息处理
_M.stream = {}

local get_token = require 'data.account.token'
local add_client = require 'ms.gate.client.add'
local del_client = require 'ms.gate.client.del'
local login_in_other_service = require 'api.login_in_other_service'
local broadcast = require 'ms.service.message.broadcast'

--有新连接进入
_M.stream.on_connect = function(client,args)
	--check connect args
	args.uid = tonumber(args.uid)
	if not args.uid or not args.sign then return false,'no sign data' end
	--check sign
	local token = get_token(args.uid)
	if not token then return false,'this user is not login.' end
	local mysign = ngx.md5(args.uid .. token)
	if mysign ~= args.sign then return false,'wrong sign' end
	
	local oldclient = cache.get('ms.gate.user.' .. args.uid)
	if oldclient then
		login_in_other_service({
			entity = entities.get(oldclient.userid,config.channel)
		})
	end

	add_client(client,args.uid)
	
	broadcast(config.channel,1,'',args.uid,config.channel)
	
	return true
end

--消息处理
local wrong_request_respond = cjson.encode({
	data = 'wrong request',
	status = -1,
})

local request = require 'ms.service.message.request'
local make_client_message = require 'data.message.make'

_M.stream.on_message = function(client,head,data)
	console('receive one message -> ',cjson.encode(data))

	local result = ''
	
	if not head or not data then
		--数据错误
		result = wrong_request_respond
	else
		--请求数据
		local ok,rs = request(config.channels.logic,data.cmd,data.data,client.userid,config.channel)
		if ok then
			local res = cjson.decode(rs)
			local status = 0
			if not res or not res.data then
				status = -1
				res = rs
			else
				status = res.status
				res = res.data
			end
			result = make_client_message(data,res,status,data.extra)
		else
			result = make_client_message(data,'this has a error -> ' .. tostring(rs),-1,data.extra)
		end
	end
	
	client:send(result)
end

--连接断开
_M.stream.on_close = function(client,close_reason)
	--广播登出消息
	if client.userid and not client.login_in_other_service then
		broadcast(config.channel,2,'',client.userid,config.channel)
	end
	del_client(client)
end

return _M