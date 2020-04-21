--[[
服务管理
--]]
local t_remove = table.remove
local t_insert = table.insert
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs

local cache = core.cache
local console = core.log.info
local cjson = core.cjson
local config = config

--路由管理
local Routes = cache.get('Routes')
--监听管理
local Listen = cache.get('Listen')
--负载管理，默认为轮询
local Balance = cache.get('Balance')

if not Routes then
	Routes = {}
	cache.set('Routes',Routes)
end

if not Listen then
	Listen = {}
	cache.set('Listen',Listen)
end

if not Balance then
	Balance = {
		--所有服务
		service = {},
		--已注册策略
		cache = {}
	}
	cache.set('Balance',Balance)
end

local _M = {}

--添加一个对象到列表中，如果已存在则不添加
local add_item_to_array = function(item,array)
	local badd = false
	for _,v in ipairs(array) do
		if v == item then
			badd = true
			break
		end
	end
	if not badd then
		t_insert(array,item)
	end
	return #array
end

--从列表中删除一个对象
local del_item_from_array = function(array,item)
	for i,v in ipairs(array) do
		if v == item then
			t_remove(array,i)
			break
		end
	end
	return
end

--添加路由
--以服务的channel为索引
--list 服务列表  以服务的sid为索引
--num 服务个数
local add_route = function(service)
	if not service.cid then return end
	local cid = service.cid
	local sid = service.sid
	
	Routes[cid] = Routes[cid] or {}
	Routes[cid].list = Routes[cid].list or {}
	if not sid or Routes[cid].list[sid] then
		sid = #Routes[cid].list + 1
		service.sid = sid
	end
	
	if not Routes[cid].list[sid] then
		--记录服务数量
		Routes[cid].num = (Routes[cid].num or 0) + 1
	end
	--记录服务对象
	Routes[cid].list[sid] = service
	
	--console('Routes ->')
	--for cid,obj in pairs(Routes) do
	--	for sid,service in pairs(obj.list) do
	--		console(cid,'->',sid)
	--	end
	--end
	
	return true
end

--删除一个路由
local del_route = function(service)
	if not service.cid then return end
	local cid = service.cid
	local sid = service.sid
	
	if Routes[cid] and Routes[cid].list then
		Routes[cid].list[sid] = nil
		Routes[cid].num = Routes[cid].num - 1
		--如果改频道已无服务，清除
		if Routes[cid].num == 0 then
			Routes[cid] = nil
		end
	end
	
	return true
end

--添加一个负载策略
--第一层以管理对象的服务的channel为索引
--第二层以对象的类型为索引
--第三层以对象的id为索引
--值为服务对象
local add_balance_cache = function(entityid,entitytype,service)
	if not entityid or not entitytype then return false end
	local cid = service.cid
	local oldservice = nil
	if Balance.cache[cid] then
		if Balance.cache[cid][entitytype] then
			oldservice = Balance.cache[cid][entitytype][entityid]
			Balance.cache[cid][entitytype][entityid] = service
			return true,oldservice
		else
			Balance.cache[cid][entitytype] = {}
		end
	else
		Balance.cache[cid] = {}
		Balance.cache[cid][entitytype] = {}
	end
	
	oldservice = Balance.cache[cid][entitytype][entityid]
	Balance.cache[cid][entitytype][entityid] = service
	return true,oldservice
end

--删除一个负载策略
local del_balance_cache = function(service)
	for cid,uts in pairs(Balance.cache) do
		for ut,entids in pairs(uts) do
			for entityid,ser in pairs(entids) do
				if ser == service then
					entids[entityid] = nil
				end
			end
		end
	end
	
	return true
end

--添加一个服务到负载管理
--以服务的channel为索引
--list 服务列表(array)
--cur 上一次提供服务的序号
local add_balance = function(service)
	if not service.cid then return false end
	local cid = service.cid
	
	Balance.service[cid] = Balance.service[cid] or {}
	Balance.service[cid].list = Balance.service[cid].list or {}
	Balance.service[cid].cur = Balance.service[cid].cur or 1
	
	add_item_to_array(service,Balance.service[cid].list)
	if not Balance.service[cid].list[Balance.service[cid].cur] then
		Balance.service[cid].cur = 1
	end
	
	return true
end

--删除一个服务
local del_balance = function(service)
	if not service.cid then return false end
	local cid = service.cid
	
	if Balance.service[cid] then
		del_item_from_array(Balance.service[cid].list,service)
		--从已注册策略中清除与之相关的策略
		del_balance_cache(service)
	end
	
	return true
end

--获取一个服务
--默认采用先模后轮询方式
local get_route_balance = function(cid,entityid,entitytype,baddbalance)
	--core.log.info('get_route_balance ',cid,'-',entityid,'-',entitytype)
	local service = nil
	--已有策略
	if entityid and entitytype and Balance.cache[cid] and Balance.cache[cid][entitytype] then
		service = Balance.cache[cid][entitytype][entityid]
		--console('route exist ',cid,'-',entityid,'-',entitytype)
	end
	
	if not service then
		if Balance.service[cid] then
			if entityid then	--mod
				local idx = entityid % (#Balance.service[cid].list) + 1
				service = Balance.service[cid].list[idx]
				--if not service then
				--	console('route add ',cid,'-',entityid,'-',entitytype,' error -->', #Balance.service[cid].list,'-',idx)
				--end
			else
				service = Balance.service[cid].list[Balance.service[cid].cur]
				if not service and #Balance.service[cid].list > 0 then
					Balance.service[cid].cur = 1
					service = Balance.service[cid].list[1]
				end
				
				Balance.service[cid].cur = Balance.service[cid].cur + 1
			end
			--console('route add ',cid,'-',entityid,'-',entitytype)
		end
		--添加策略
		if service and baddbalance then
			--core.log.info('add_balance_cache ',cid,'-',entityid,'-',entitytype)
			add_balance_cache(entityid,entitytype,service)
		end
	end
	
	return service
end

--Listen[channel_id][command_id].Channels = [service_channelids]
--command_id == 0  -->该频道中的所有消息监听队列
--Listen[channel_id][command_id].Others = [services] --所有无channelid的服务监听列表
local add_listen = function(service)
	if not service.listen then
		service.listen = {}
	end
	
	--不能监听本频道的所有消息
	--if service.cid then
	--	service.listen[service.cid] = 'all'
	--end
	
	--service.listen
	--[channel_id] = {command_id1,command_id2} --消息号列表
	--[channel_id] = 'all' --全部消息
	for cid,cmds in pairs(service.listen) do
		cid = tonumber(cid)
		Listen[cid] = Listen[cid] or {}
		if cmds == 'all' then
			cmds = {0}
		end
		for i,cmd in ipairs(cmds) do
			if cmd == 0 then
				cmds = {0}
				break
			end
		end

		for i,cmd in ipairs(cmds) do
			cmd = tonumber(cmd)
			--生成监听队列
			Listen[cid][cmd] = Listen[cid][cmd] or {}
			if service.cid then
				--如果服务有频道id,则将服务添加到对应的频道中
				Listen[cid][cmd].Channels = Listen[cid][cmd].Channels or {}
				add_item_to_array(service.cid,Listen[cid][cmd].Channels)
			else
				--如果服务没有频道id,默认为无对等服务
				Listen[cid][cmd].Others = Listen[cid][cmd].Others or {}
				add_item_to_array(service,Listen[cid][cmd].Others)
			end
		end
	end
	
	--console('Listen ->')
	--for cid,cmds in pairs(Listen) do
	--	for cmd,obj in pairs(cmds) do
	--		for i,ccid in ipairs(obj.Channels or {}) do
	--			console(cid,'-',cmd,'-->',ccid)
	--		end
	--		for i,service in ipairs(obj.Others or {}) do
	--			console(cid,'-',cmd,'-->',service.sid)
	--		end
	--	end
	--end
end

--清除一个服务的监听
local del_listen = function(service)
	if service.cid then
		if not Routes[service.cid] then
			--当该频道没有服务时，清除监听
			for cid,cmds in pairs(Listen) do
				--在每个频道中去查找服务
				for cmd,listen_objs in pairs(cmds) do
					--在每个消息监听列表中查找
					del_item_from_array(listen_objs.Channels or {},service.cid)
					if #listen_objs.Channels == 0 then
						listen_objs.Channels = nil
						if not listen_objs.Others then
							cmds[cmd] = nil
						end
					end
				end
			end
		end
	else
		for cid,cmds in pairs(Listen) do
			--在每个频道中去查找服务
			for cmd,listen_objs in pairs(cmds) do
				--在每个消息监听列表中查找
				if listen_objs.Others then
					del_item_from_array(listen_objs.Others or {},service)
					if #listen_objs.Others == 0 then
						listen_objs.Others = nil
						if not listen_objs.Channels then
							cmds[cmd] = nil
						end
					end
				end
			end
		end
	end
	return
end

--服务注册
_M.add = function(service)
	if not service then return false,'wrong params' end
	service.cid = service.cid and tonumber(service.cid) or nil
	service.sid = service.sid and tonumber(service.sid) or nil
	
	add_route(service)
	add_balance(service)
	add_listen(service)
	
	console('register one service cid = ',service.cid, ' number = ',service.number)
	return true
end

_M.add_balance = add_balance_cache

--服务注销
_M.remove = function(service)
	if not service then return false,'wrong params' end
	service.cid = service.cid and tonumber(service.cid) or nil
	service.sid = service.sid and tonumber(service.sid) or nil
	
	del_route(service)
	del_listen(service)
	del_balance(service)
	
	return true
end

--广播
_M.broadcast = function(cid,cmd,msg,entityid,entitytype)
	local sendcount = 0
	cid = tonumber(cid)
	cmd = tonumber(cmd)
	if not cid or not cmd or cid == 0 or cmd == 0 then
		return false,'wrong cmd'
	end
	if entityid == 0 then entityid = nil end
	entitytype = entitytype or 0
	
	if not Listen[cid] then 
		return true
	end
	--监听该频道(cid)所有消息
	if Listen[cid][0] then
		if Listen[cid][0].Others then
			for _,service in ipairs(Listen[cid][0].Others) do
				service:send(msg)
				sendcount = sendcount + 1
			end
		end
		if Listen[cid][0].Channels then
			for _,_cid in ipairs(Listen[cid][0].Channels) do
				local service = get_route_balance(_cid,entityid,entitytype,true)
				if service then
					service:send(msg)
					sendcount = sendcount + 1
				end
			end
		end
	end
	
	--监听该频道(cid)对应消息(cmd)
	if Listen[cid][cmd] then
		if Listen[cid][cmd].Others then
			for _,service in ipairs(Listen[cid][cmd].Others) do
				service:send(msg)
				sendcount = sendcount + 1
			end
		end
		if Listen[cid][cmd].Channels then
			for _,_cid in ipairs(Listen[cid][cmd].Channels) do
				local service = get_route_balance(_cid,entityid,entitytype,true)
				if service then
					service:send(msg)
					sendcount = sendcount + 1
				end
			end
		end
	end
	cache.set('ms.controller.send.count',(cache.get('ms.controller.send.count') or 0) + sendcount)
	
	return true,sendcount
end

--转发
_M.transfer = function(cid,sid,msg,entityid,entitytype,baddbalance)
	if not cid then return false,'wrong cid = ' .. cid end
	if not Routes[cid] then return false,'no such service. channel id = ' .. cid end
	
	local service = nil
	
	if not sid or sid == 0 then
		if entityid == 0 then entityid = nil end
		service = get_route_balance(cid,entityid,entitytype or 0,baddbalance)
	else
		service = Routes[cid].list[sid]
	end
	
	if service then
		--console('the service no.',service.sid,' send message')
		service:send(msg)
		cache.set('ms.controller.send.count',(cache.get('ms.controller.send.count') or 0) + 1)
	else
		--返回消息转发错误
		return false,'No service can process this message.'
	end
	
	return true
end

return _M