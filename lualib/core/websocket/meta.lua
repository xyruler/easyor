--[[
websocket方法集
--]]
local sleep = ngx.sleep
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local kill = ngx.thread.kill

local errlog = require 'core.log'.error
local Server = require "resty.websocket.server"
local Client = require "resty.websocket.client"
local semaphore = require "ngx.semaphore"

local t_remove = table.remove
local t_insert = table.insert

local _M = {}
_M._VERSION = '0.01'

--发送消息
--主动发送的消息中，没有ping pong消息
local function send(self,content,ty)
	local bytes, err = true, nil
	if ty == "close" then
		if content.code == 0 then
			if self.on_close then
				self.on_close(self,break_err)
			end
			self.conn.fatal = true
		elseif self.conn and not self.conn.fatal then
			self.conn:send_close(content.code, content.reason or content.code)
		end
	elseif self.conn and not self.conn.fatal then
		if ty == "string" or ty == "number" then
			bytes,err = self.conn:send_text(content)
		else
			bytes,err = self.conn:send_binary(content)
		end
	end
	
	--core.log.info('send message -> ',ty, ' -- err = ',err)

	return bytes,err
end

--推送消息
local function push(self)
	if not self.push_msgs then return end
	
	local n = 0
	self.push_idx = self.push_idx or 1
	local total = #self.push_msgs
	for i = self.push_idx,total do
		local msg = self.push_msgs[i]
		local bytes,err = send(self,msg.content,msg.ty)
		if not bytes then return end
		self.push_idx = self.push_idx + 1
		n = n + 1
		--防止消息过多，独占进程cpu，每发5个消息暂停一次
		if n == 5 then
			sleep(0.000001)
			n = 0
		end
	end
	
	self.push_msgs = nil
	self.push_idx = nil
end

--推送消息协程
local function push_thread(self)
	while true do
		if not self.conn or self.conn.fatal then return end
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
--self.on_message = function(self,data,type) end
--self.on_close = function(self,errmsg) end
local function heart_thread(self)
	while self.conn and not self.conn.fatal do
		local ok,err = self.conn:send_ping()
		sleep(self.heart)
	end
end

--接收消息协程
local function receive_thread(self)
	local break_err = nil
	local server_receive_close = false
	
	local msgnum = 0
	local totaltime = 0
	while not self.conn.fatal do
		local data, ty, err = self.conn:recv_frame()
		--core.log.info('receive message -> ',ty)
		--出错后直接关闭
		if self.conn.fatal then
			break_err = 'fatal err = ' .. (err or 'unknown')
			break
		end
		msgnum = msgnum + 1
		--根据类型进行处理
		if ty == "ping" then
			--ping pong消息
			self.conn:send_pong()
		elseif ty == "text" or ty == "binary" then
			self.on_message(self,data or "",ty)
		elseif ty == "close" then
			if self.conn.close then
				--如果是客户端，关闭连接
				self.conn:close()
			else
				--如果是服务端，标记关闭
				self:close(0)
				server_receive_close = true
				if self.thread_heart then
					kill(self.thread_heart)
					self.thread_heart = nil
				end
			end
			break_err = 'close code = ' .. (err or 'unknown')
			break
		end
	end
	--回调关闭
	if self.on_close and not server_receive_close then
		self.on_close(self,break_err)
	end
end

--启动心跳
function _M:active_heart(heart_interval)
	if not self.conn or self.conn.fatal then return false end
	self.heart = tonumber(heart_interval or 3)
	if self.heart and self.heart > 0 then
		self.thread_heart = spawn(heart_thread,self)
	end
	return true
end

--停止，清除各个协程
local _stop = function(self)
	if self.thread_receive then
		kill(self.thread_receive)
		self.thread_receive = nil
	end
	if self.thread_push then
		kill(self.thread_push)
		self.thread_push = nil
	end
	if self.thread_heart then
		kill(self.thread_heart)
		self.thread_heart = nil
	end
end

--启动
local _start = function(self)
	if not self.conn then return false end
	
	_stop(self)
	
	if self.on_message then
		self.thread_receive = spawn(receive_thread,self)
	end
	self.thread_push = spawn(push_thread,self)
	
	if self.heart then self:active_heart(self.heart) end
end

--重连，仅客户端可用
function _M:reconnect()
	if not self.host then return false,'this is a service' end

	if self.conn and not self.conn.fatal and not self.conn.closed then
		return true,'the connect is healthy'
	end
	
	self.connect_count = (self.connect_count or 0) + 1
	self.conn = Client:new{
		timeout = self.timeout or 0,
		max_payload_len = self.max_payload_len or 65535,
	}
	local ok,err = self.conn:connect(self.host)
	if not ok then
		self.conn = nil
		return false,err
	end
	
	_start(self)
	
	return true
end

--启动
function _M:run(on_message,on_close,heart_interval)
	self.on_message = on_message
	self.on_close = on_close
	self.heart = heart_interval
	if not self.message_threads_seam then self.message_threads_seam = semaphore:new() end
	
	if not self.conn then
		if self.host then 
			return self:reconnect() 
		else
			self.conn = Server:new{
				timeout = self.timeout or 0,
				max_payload_len = self.max_payload_len or 65535,
			}
		end
	end
	
	_start(self)
	
	return true
end

--发送消息
function _M:send(content,ty)	
	if not self.conn or self.conn.fatal then return false end
	ty = ty or type(content)
	local count = #self.msg
	--最大允许阻塞5000个消息
	if count > 5000 then
		errlog('message pool full')
		return false
	end
	self.msg[count + 1] = {content = content,ty = ty}
	self.sema:post(1)
	return true
end

--关闭
function _M:close(code,reason)
	if not self.conn or self.conn.fatal then return false end
	self:send({
		code = code or 1000,
		reason = reason,
	},"close")
	if not self.on_message and self.on_close then
		self.on_close(self,reason or 'close code = ',code or 1000)
	end
end

return _M