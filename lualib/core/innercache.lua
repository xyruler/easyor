--[[
worker内部缓存
--]]
local sleep = ngx.sleep
local now = ngx.time

local clone = require 'core.clone'
local go = require 'core.go'

--缓存数据
---[[
--分开保存，是为了便于过期缓存的清除
local data_t = {}		--记录缓存过期的时间戳
local data_v = {}		--以时间戳为索引的缓存集合
local st = now()

--清除过期缓存
local clear = false
clear = function()
	local et = now()
	local n = 0
	--按时间点逐点清除
	for t = st,et do
		if data_v[t] then
			--存在缓存
			for k,_ in pairs(data_v[t]) do
				n = n + 1
				data_t[k] = nil
				if n >= 100 then
					n = 0
					sleep(0.1) 
				end
			end
			data_v[t] = nil
		end
	end
	st = et
	
	go(300,clear)
end

local _M = {}

_M.get = function(k,copy)
	local t = data_t[k]
	--没有找到对应的时间戳，无缓存
	if not t then return nil end
	--时间戳过期
	if t > 0 and t < now() then return nil end
	--缓存数据出现错误，更新状态
	if not data_v[t] then
		data_t[k] = nil
		return nil
	end
	--返回缓存或缓存副本
	if copy then
		return clone(data_v[t][k])
	else
		return data_v[t][k]
	end
end

--
_M.set = function(k,v,outtime,copy)
	--过期时间，0表示永不过期
	outtime = outtime or 0
	--清除原缓存记录
	local t = data_t[k]
	if t and data_v[t] then data_v[t][k] = nil end
	if outtime == 0 then
		t = 0
	else
		t = now() + outtime
	end
	--记录新缓存
	data_t[k] = t
	data_v[t] = data_v[t] or {}
	if copy then
		data_v[t][k] = clone(v)
	else
		data_v[t][k] = v
	end
	return true
end

--删除缓存
_M.del = function(k)
	local t = data_t[k]
	if t and data_v[t] then data_v[t][k] = nil end
	data_t[k] = nil
	return true
end

--启动缓存清理协程
_M.open_clear = function()
	go(300,clear)
end

return _M

