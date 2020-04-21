--[[
websocket客户端
--]]
local semaphore = require "ngx.semaphore"
local sleep = ngx.sleep
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local kill = ngx.thread.kill


local _M = {}

local mt = { __index = _M }

function _M:new(eid,et)
	if not eid then return false,'no eid' end
	
	return setmetatable({
        messages = {},
		heart = false,
		sema = semaphore:new(),
		eid = eid,
		et = et,
    }, mt)
	
end

local _process_message_thread = function(self)
	while true do
		local msgs = self.messages
		local total = #msgs
		
		self.messages = {}
		for i = 1,total do
			self.on_message(self,msgs[i].head,msgs[i].data)
			sleep(0.000001)
		end
		
		if self.kill then break end
		
		self.sema:wait(300)
	end
	
end

function _M:init(on_message)
	self.on_message = on_message
	if not self.on_message then return false end
	self.thread_on_message = spawn(_process_message_thread,self)
	return true
end

function _M:append_message(message)
	if self.kill then return false,'The entity has been destroyed' end
	self.messages[#self.messages + 1] = message
	self.sema:post(1)
end

function _M:destory()
	self.kill = true
	if self.thread_on_message then
		wait(self.thread_on_message)
	end
end

return _M