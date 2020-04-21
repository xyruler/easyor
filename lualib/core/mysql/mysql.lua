--[[
mysql对象
--]]
local class = require "core.class"
local mysql = require "resty.mysql"

local get_address = require 'core.dns.getaddress'

local _M = class()

function _M:__init(host,port,user,password,database)
	self.host = get_address(host)
	self.port = port
	self.user = user
	self.password = password
	self.database = database
	self:open()
end

function _M:open()
	if self.con then return true,"success" end
	local con = mysql:new()
	if not con then return false,"create mysql connect failed." end
	con:set_timeout(30000)
	local result,errmsg,errno,state = con:connect({
		host = self.host,
		port = self.port,
		user = self.user,
		password = self.password,
		database = self.database
	})
	if not result then
		return false,errmsg
	end
	self.con = con
	self:query("SET NAMES 'utf8'")
	return true,"success"
end

function _M:query(sql)
	if not self.con then
		if not self:open() then	return false,"no connect" end
	end
	local result, errmsg, errno, sqlstate = self.con:query(sql)
	if not result then self:close(true) end
    return result, errmsg
end

function _M:close(realy)
	if self.con then
		if realy then 
			self.con:close()
		else
			self.con:set_keepalive(60000, 100)
		end
	end
	self.con = nil
end

return _M