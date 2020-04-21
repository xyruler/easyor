--[[
tcp对象方法集
--]]
--tcp消息头结构 必需
--_M.stream.head = require 'data.message.head' 
--[[
_M.stream.head = {
	size = 8,
	get = function(data) --根据data生成head对象，head对象中必须包含size属性 
	end,
	attr_size_name = 'MessageSize' --head对象中size属性的属性名
	tostring = function(data) end
	make = function(channel,command,entitytype,entityid,datasize) end --根据参数构建消息头
}
--]]

--_M.stream.heart = require 'data.message.heart'
--[[
_M.stream.heart = {	--激活心跳  可选
	interval = 5,	--心跳间隔
	get_data = function() end,		--心跳包数据
}
--]]

local sleep = ngx.sleep
local spawn = ngx.thread.spawn
local kill = ngx.thread.kill
local semaphore = require "ngx.semaphore"

local errlog = require 'core.log'.error

local t_remove = table.remove
local t_insert = table.insert

local _M = {}

--推送消息
local function push(self)
	if not self.push_msgs then return end
	
	local n = 0
	self.push_idx = self.push_idx or 1
	local total = #self.push_msgs
	for i = self.push_idx,total do
		local msg = self.push_msgs[i]
		local bytes,err = self.sock:send(msg)
		if not bytes then return end
		self.push_idx = self.push_idx + 1
		n = n + 1
		--防止消息过多，独占进程cpu，每发5个消息暂停一次
		if n == 5 then sleep(0.00001) end	
	end
	
	self.push_msgs = nil
	self.push_idx = nil
end

--推送消息协程
local function push_thread(self)
	while true do
		if not self.sock then return end
		--先发送推送消息列表中的消息
		if self.push_msgs then
			push(self)
		elseif #self.msg > 0 then
			--将消息列表转移到推送消息列表中
			self.push_msgs = self.msg
			self.msg = {}
			push(self)
		end
		--等待下一条消息
		self.sema:wait(300)
	end
end

--心跳协程
--[[
self.heart = {
	interval = 3,	--心跳间隔
	get_data = function() end,		--心跳包数据
}
--]]
local function heart_thread(self)
	while self.sock and self.heart do
		local ok,err = self.sock:send(self.heart.get_data())
		sleep(self.heart.interval)
	end
end

--接收消息协程
--[[
self.head = {
	size = 11,					--消息头大小
	get = function(str) end, 	--消息头解析函数
	attr_size_name = '',		--消息头中表示消息体大小的属性字段名
}
self.on_message = function(self,head,data) end
--]]
local function receive_thread(self)
	local break_err = nil
	while true do
		--获取消息头
		local data, err = self.sock:recv_frame(self.head.size)
		if not data then
			break_err = 'receive head on error data'
			errlog('receive head on error data')
			self.sock:close()
			break
		end
		--解析消息头
		local head = self.head.get(data)
		if not head then
			break_err = 'head parser failed'
			errlog('head parser failed')
			self.sock:close()
			break;
		end
		--获取消息体
		local data, err = self.sock:recv_frame(head[self.head.attr_size_name])
		if not data then
			break_err = 'receive body on error data'
			errlog('receive body on error data')
			self.sock:close()
			break
		end
		--非同步时，启动新的协程
		if async then
			spawn(self.on_message,self,head,data)
		else
			self.on_message(self,head,data)
		end
	end
	
	return true,break_err
end

--停止，清除各个协程
local _stop = function(self)
	if self.thread_push then
		kill(self.thread_push)
		self.thread_push = nil
	end
	if self.thread_heart then
		kill(self.thread_heart)
		self.thread_heart = nil
	end
	
	if self.thread_receive then
		kill(self.thread_receive)
		self.thread_receive = nil
	end
end

--启动
--block --是否同步执行接收协程
local _start = function(self,block)
	if not self.sock then return false end
	if not self.head or not self.head.size or not self.head.get or not self.head.attr_size_name then return false end

	_stop(self)
	
	self.seam = semaphore:new()
	self.msg = self.msg or {}
	
	self.thread_push = spawn(push_thread,self)
	
	if self.heart and self.heart.interval and self.heart.data then 
		self.thread_heart = spawn(heart_thread,self)
	end
	
	if self.on_message then
		if block then
			return receive_thread(self)
		else
			self.thread_receive = spawn(thread_receive,self)
		end
	end
	
	return true
end

--发送消息
local _send = function(content)	
	if not self.sock then return false end
	local count = #self.msg
	--最大允许阻塞5000个消息
	if count > 5000 then
		errlog('message pool full')
		return false
	end
	self.msg[count + 1] = content
	self.sema:post(1)
	return true
end

--关闭
local _close = function()
	if not self.sock then return false end
	self.sock:close()
	_stop(self)
end

_M.start = _start
_M.send = _send
_M.close = _close

return _M