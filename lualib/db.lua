--[[
db数据加载
目前支持mysql redis
--]]
local config = require 'config'
local mysql = require 'core.mysql'
local redis = require 'core.redis'

local log_err = core.log.error

local _M = {}

for dbname,opts in pairs(config.db or {}) do
	if opts.type == 'mysql' then
		if not opts.host or not opts.port or not opts.user or not opts.database then
			log_err('Mysql configuration has wrong parameters. mysql name = ',dbname)
		else
			_M[dbname] = mysql.get_con_pool(opts)
		end
	elseif opts.type == 'redis' then
		if not opts.host or not opts.port then
			log_err('Redis configuration has wrong parameters. redis name = ',dbname)
		else
			_M[dbname] = redis:new(opts)
		end
	end
end

return _M