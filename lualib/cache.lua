--[[
缓存加载
仅支持mysql数据库
--]]
local s_find = string.find
local s_sub = string.sub
local s_len = string.len
local fmt = string.format
local t_concat = table.concat

local tostring = tostring

local mlcache = require 'resty.mlcache'
local config = config
local ngx = ngx
local sqlsafe = ngx.quote_sql_str
local console = core.log.info

local cjson = require 'core.cjson'

local clone = require 'core.clone'
local mysql = require 'core.mysql'
local redis = require 'core.redis'

local _M = {version = 0.1}

--分割缓存key
local split = function(str)
	local keys = {}
	--[[
	local exts = nil
	local start = 1
	local count = 1
	local ef = s_find(str,'|',1,true)
	if ef then
		ef = ef - 1
		local extstr = s_sub(str,ef + 2)
		
		while true do
			local pos = s_find(extstr,'|',start,true)
			if not pos then
				break
			end
			exts[count] = s_sub(str,start,pos - 1)
			count = count + 1
			start = pos + 1
		end
		
		exts[count] = s_sub(str,start)
	else
		ef = nil
	end
	--]]
	local start = 1
	local count = 1
	while true do
		local pos = s_find(str,':',start,true)
		if not pos then
			break
		end
		keys[count] = s_sub(str,start,pos - 1)
		count = count + 1
		start = pos + 1
	end
	
	--keys[count] = s_sub(str,start,ef)
	keys[count] = s_sub(str,start)
	
	return keys,exts
end

--获取函数方法
local _get_function = function(path)
	if type(path) ~= 'function' then return path end
	
	local ok,fun = pcall(require,path)
	if ok and type(fun) == 'function' then
		return fun
	end
	return nil
end

--从mysql数据库中获取数据
local _get_from_mysql = function(ctx,key)
	--拆解key
	local keyvals,attrs = split(key)
	--检查key列表数量
	local keynum = #keyvals
	if keynum ~= #ctx.keys then
		return nil,'the key error.'
	end
	--组装sql语句中的where条件
	local keys_select_str = {}
	for i,k in ipairs(ctx.keys) do
		keys_select_str[i] = '`' .. k .. '`=' .. sqlsafe(keyvals[i])
	end
	--获取表名
	local tablename = ctx.table
	if ctx.get_table_name then
		tablename = ctx.get_table_name(key) or ctx.table
	end

	--执行sql
	local rs,err = mysql.query(ctx.slave,ctx.value_select_str .. tablename .. '` WHERE ' .. t_concat(keys_select_str,' AND ') .. ' LIMIT 1')
	
	if not rs then return nil,err end
	
	if #rs == 0 then return nil end
	--if #rs ~= 1 then return nil,'the more result is get.' end
	--保存表字段列表
	if not ctx.value_keys then
		ctx.value_keys = {}
		local c = 1
		for k,_ in pairs(rs[1]) do
			ctx.value_keys[c] = k
			c = c + 1
		end
	end
	
	if #rs == 1 then
		return rs[1]
	end
	--如果获取的是列表，进行标记
	--sql中使用了limit 1，此处语句不会被执行
	--多结果处理功能未实现
	rs.__data_type = 'list'
	
	return rs
end

--从redis中获取数据
local _get_from_redis = function(ctx,key)
	
	return nil,'to do ...'
end

--创建数据获取方法
local make_get_from_db_function = function(opts)
	opts.get_from_db = _get_function(opts.get_from_db)
	if opts.get_from_db then
		return function(key)
			return opts.get_from_db(opts,key)
		end
	end
	
	local ctx = opts.database
	if ctx then
		if ctx.type == 'mysql' then
			if ctx.slave and ctx.table and ctx.keys then
				return function(key)
					return _get_from_mysql(ctx,key)
				end
			end
		elseif ctx.type == 'redis' then
			return function(key)
				return _get_from_redis(ctx,key)
			end
		end
	end
	
	return function(key)
		return nil
	end

end

--将缓存值转换为字符串
local _value_to_string = function(value)
	local t = type(value)
	if t == 'table' then
		local json, err = cjson.encode(value)
        if not json then
            return nil, "could not encode table value: " .. err
        end
        return json
	elseif t == 'string' then
		return value
	elseif t == 'boolean' then
		return value and 1 or 0
	else
		return tostring(value)
	end
end

--将数据保存到mysql中
local _save_to_mysql = function(ctx,key,value,bnew)
	--检查参数
	if type(value) ~= 'table' then
		return nil,nil,'wrong data type'
	end
	if value.__data_type and value.__data_type ~= 'row' then
		return nil,nil,'wrong data type'
	end
	--检查key
	local keyvals,attrs = split(key)
	local keynum = #keyvals
	if keynum ~= #ctx.keys then
		return nil,nil,'the key error.'
	end
	
	if not attrs then
		attrs = ctx.value_keys
	end
	local sql_str
	
	local values = {}
	local n = 1
	--获取表名
	local tablename = ctx.table
	if ctx.get_table_name then
		tablename = ctx.get_table_name(key) or ctx.table
	end
	--保存数据
	if bnew then
		--如果是新数据，准备插入
		local keys = {}
		--组装sql
		if not attrs then
			for k,v in pairs(value) do
				keys[n] = '`' .. k .. '`'
				values[n] = sqlsafe(_value_to_string(v))
				n = n + 1
			end 
		else
			for i,k in ipairs(attrs) do
				if value[k] then
					keys[n] = '`' .. k .. '`'
					values[n] = sqlsafe(_value_to_string(value[k]))
					n = n + 1
				end
			end
		end
		if n == 1 then
			return nil
		end
		sql_str = 'INSERT INTO `' .. tablename .. '` (' .. t_concat(keys,',') .. ') VALUES (' .. t_concat(values,',') .. ')'
	else
		--已有数据，进行更新
		--组装sql
		if not attrs then
			for k,v in pairs(value) do
				values[n] = '`' .. k .. '`=' .. sqlsafe(_value_to_string(v))
				n = n + 1
			end
		else
			for i,k in ipairs(attrs) do
				if value[k] then
					values[n] = '`' .. k .. '`=' .. sqlsafe(_value_to_string(value[k]))
					n = n + 1
				end
			end
		end
		if n == 1 then
			return nil
		end
		
		local keys_select_str = {}
		for i,k in ipairs(ctx.keys) do
			keys_select_str[i] = '`' .. k .. '`=' .. sqlsafe(keyvals[i])
		end
		sql_str = 'UPDATE `' .. tablename .. '` SET ' .. t_concat(values,',') .. ' WHERE ' .. t_concat(keys_select_str,' AND ')
	end
	--执行sql
	local rs,err = mysql.query(ctx.master,sql_str)
	if bnew and not err and ctx.auto_incr and rs.insert_id then
		--新数据，有自增id时，更新key
		value[ctx.auto_incr] = rs.insert_id
		key = {}
		for i,kk in ipairs(ctx.keys) do
			key[i] = value[kk]
		end
		key = t_concat(key,':')
	end
	--返回保存结果
	return key,value,err
end

--保存数据到redis
local _save_to_redis = function(ctx,key,value,bnew)

end

--创建数据保存方法
local make_save_to_db_function = function(opts)
	opts.save_to_db = _get_function(opts.save_to_db)
	if opts.save_to_db then
		return function(key,value,bnew)
			return opts.save_to_db(opts,key,value,bnew)
		end
	end
	
	local ctx = opts.database
	if not ctx then return nil end
	
	if ctx.type == 'mysql' then
		if not ctx.keys or not ctx.table and not ctx.master then return nil,'wrong db scheme' end
		
		return function(key,value,bnew)
			return _save_to_mysql(ctx,key,value,bnew)
		end
	elseif ctx.type == 'redis' then
		return function(key,value,bnew)
			return _save_to_redis(ctx,key,value,bnew)
		end
	end

	return nil
end

--从缓存中获取数据
local _get = function(self,key,copy)
	key = tostring(key)
	--更新缓存
	self.cache:update()
	--获取缓存值
	
	local value,err,hitlevel = self.cache:get(key,self.opts,self.get_from_db,key)
	if err then
		return nil,'get value failed. err = ' ..err
	end
	
	if not value then return value end
	--如果要求复制，则返回副本
	if copy then
		return clone(value)
	else
		return value
	end
end

--批量获取缓存值
local _get_bulk = function(self,bulk)
	for i = 3,bulk.n,4 do
		bulk[i] = bulk[i] or self.get_from_db
		bulk[i + 1] = bulk[i + 1] or bulk[i - 2]
	end

	return self.cache:get_bulk(bulk,{concurrency = self.opts.concurrency})
end

--创建批量获取列表
local _new_bulk = function(self,n_lookups)
	return mlcache.new_bulk(n_lookups)
end

--批量获取的缓存值列表遍历方法
local _each_bulk_res = function(self,res)
	return mlcache.each_bulk_res(res)
end

--touch缓存，判定缓存是否存在
local _peek = function(self,key)
	key = tostring(key)
	return self.cache:peek(key)
end

--设置缓存值
local _set = function(self,key,value,copy)
	key = tostring(key)
	if copy and value ~= nil then
		value = clone(value)
	end
	
	--先保存到数据库
	if self.save_to_db then
		local oldvalue = self:get(key)
		local err = false
		if oldvalue then
			--如果旧缓存中有新值不存在的数据，则更新到新值中
			for k,v in pairs(oldvalue) do
				if not value[k] then value[k] = v end
			end
		end
		--保存
		key,value,err = self.save_to_db(key,value,oldvalue == nil)
		if err then
			return false,err
		end
	end
	--再保存到缓存，并通知其他work
	local ok,err = self.cache:set(key,self.opts,value)
	
	--返回新key
	if not ok then
		return false,err
	else
		return key
	end
end

--删除缓存
local _delete = function(self,key)
	key = tostring(key)
	return self.cache:delete(key)
end

--清空缓存
local _purge = function(self,flush_expired)
	return self.cache:purge(flush_expired)
end

--更新缓存
local _update = function(self)
	return self.cache:update()
end

--缓存对象列表
for k,v in pairs(config.caches or {}) do
	--缓存同步字典对象
	v.shm_miss = v.shm_miss or 'sys_cache_miss'
	v.shm_locks = v.shm_locks or 'sys_cache_locks'
	v.ipc_shm = v.ipc_shm or 'sys_cache_ipc'
	
	v.debug = config.debug
	
	if v.database and config.db then
		if v.database.type == 'mysql' then
			--初始化mysql对象
			if v.database.master then v.database.master = config.db[v.database.master] end
			if v.database.slave then 
				v.database.slave = config.db[v.database.slave]
			else
				v.database.slave = v.database.master
			end
			--默认的sql头
			if v.database.value_keys then
				v.database.value_select_str = 'SELECT `' .. t_concat(v.database.value_keys,'`,`') .. '` FROM `'
			else
				v.database.value_select_str = 'SELECT * FROM `'
			end
			--表名获取方法
			v.database.get_table_name = _get_function(v.database.get_table_name)
		elseif v.database.type == 'redis' then
			
		end
	end
	--反序列化方法
	v.l1_serializer = _get_function(v.l1_serializer)
	
	_M[k] = {
		cache = mlcache.new(k,k,v),
		opts = v,
		get_from_db = make_get_from_db_function(v),
		save_to_db = make_save_to_db_function(v),
		get = _get,
		get_bulk = _get_bulk,
		new_bulk = _new_bulk,
		each_bulk_res = _each_bulk_res,
		peek = _peek,
		set = _set,
		delete = _delete,
		purge = _purge,
		update = _update,
	}
end

return _M