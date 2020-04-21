--[[
mysql 便捷接口
--]]
local ngx = ngx
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local semaphore = require "ngx.semaphore"
local sleep = ngx.sleep
local mysql = require 'core.mysql.mysql'

local _M = {}

local cons = {}

--sql执行
local query = function(config,sql)
	local con = mysql:new(config.host,config.port,config.user,config.password,config.database)
	local retry = 0
	local rs,err = con:open()
	if rs then
		rs,err = con:query(sql)
		if err then
			core.log.info('query failed. -> ',err)
		end
	end
	con:close()
	return rs,err
end

--创建新的mysql对象
local new_con = function(config)
	return mysql:new(config.host,config.port,config.user,config.password,config.database)
end

--等待空闲mysql对象
local wait_free_con = function(con)
	while con.inuse >= con.conf.concurrency do
		con.sema:wait(1)
	end
end

--创建mysql对象池
local make_pool = function(config)
	local con = {
		inuse = 0,
		conf = config,
		concurrency = config.concurrency or 100,
		sema = semaphore:new()
	}
	
	con.query = function(self,sql)
		if self.inuse >= self.concurrency then
			wait(spawn(wait_free_con,self))
		end
		
		self.inuse = self.inuse + 1
		local rs,err = query(self.conf,sql)
		self.inuse = self.inuse - 1
		self.sema:post(1)
		return rs,err
	end
	
	return con
end

--执行sql
_M.query = function(config,sql)
	if not config.host or not config.port or not config.user or not config.database then return false,'wrong params' end

	if not config.concurrency or config.concurrency <= 0 then
		return query(config,sql)
	end
	
	local key = config.host .. config.port .. config.user .. config.database 
	
	if not cons[key] then
		cons[key] = make_pool(config)
	end
	
	return cons[key]:query(sql)
end

--获取一个mysql对象
_M.get_single_con = new_con
--获取mysql池
_M.get_con_pool = make_pool

return _M