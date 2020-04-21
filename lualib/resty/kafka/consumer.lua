-- Copyright (C) Dejiang Zhu(doujiang24)


local response = require "resty.kafka.response"
local request = require "resty.kafka.request"
local broker = require "resty.kafka.broker"
local client = require "resty.kafka.client"
local Errors = require "resty.kafka.errors"


local setmetatable = setmetatable
local timer_at = ngx.timer.at
local timer_every = ngx.timer.every
local is_exiting = ngx.worker.exiting
local ngx_sleep = ngx.sleep
local ngx_log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG
local debug = ngx.config.debug
local crc32 = ngx.crc32_short
local pcall = pcall
local pairs = pairs

local API_VERSION_V0 = 0
local API_VERSION_V1 = 1
local API_VERSION_V2 = 2

local ReplicalId = -1
local MaxWaitTime = 300

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end


local _M = { _VERSION = "0.01" }
local mt = { __index = _M }

local function default_partitioner(key, num, correlation_id)
    local id = key and crc32(key) or correlation_id

    -- partition_id is continuous and start from 0
    return id % num
end

local function correlation_id(self)
    local id = (self.correlation_id + 1) % 1073741824 -- 2^30
    self.correlation_id = id

    return id
end

local function choose_partition(self, topic, key)
    local brokers, partitions = self.client:fetch_metadata(topic)
    if not brokers then
        return nil, partitions
    end
	--if true then return 2 end

    return self.partitioner(key, partitions.num, self.correlation_id)
end

local function fetch_encode(self)
    local req = request:new(request.FetchRequest,correlation_id(self), self.client.client_id, self.api_version)

    req:int32(-1)
    req:int32(2000)
	req:int32(100)
	
	req:int32(self.topic_num)
	for topic,partitions in pairs(self.topics) do
		req:string(topic)
		req:int32(#partitions)
		for partition_id,offset in pairs(partitions) do
            req:int32(2)
            req:int64(offset)
			req:int32(1024)
        end
	end
    return req
end

local function offset_encode(self)
    local req = request:new(request.OffsetRequest,correlation_id(self), self.client.client_id, self.api_version)
	req:int32(-1)
	
	req:int32(self.topic_num)
	for topic,partitions in pairs(self.topics) do
		req:string(topic)
		req:int32(#partitions)
		for partition_id,offset in pairs(partitions) do
            req:int32(2)
            req:int64(-1)
			req:int32(1024)
        end
	end
	return req
end

local function offset_encode(self)
    local req = request:new(request.OffsetRequest,correlation_id(self), self.client.client_id, self.api_version)
	req:int32(-1)
	
	req:int32(self.topic_num)
	for topic,partitions in pairs(self.topics) do
		req:string(topic)
		req:int32(#partitions)
		for partition_id,offset in pairs(partitions) do
            req:int32(2)
            req:int64(-1)
			req:int32(1024)
        end
	end
	return req
end



local function fetch_decode(resp)
    local api_version = resp.api_version
	if api_version == API_VERSION_V1 or api_version == API_VERSION_V2 then
		local throttletime = resp:int32()
	end
	
    local topic_num = resp:int32()
    local ret = new_tab(0, topic_num)
	
    for i = 1, topic_num do
        local topic = resp:string()
        local partition_num = resp:int32()
        ret[topic] = {}

        for j = 1, partition_num do
            local partition = resp:int32()

            if api_version == API_VERSION_V0 or api_version == API_VERSION_V1 then
                ret[topic][partition] = {
                    errcode = resp:int16(),
                    offset = resp:int64(),
					data = resp:bytes(),
                }
			end
        end
    end

    return ret
end

local function offset_decode(resp)
    local api_version = resp.api_version

    local topic_num = resp:int32()
	core.log.info('topic_num = ',topic_num)
    local ret = new_tab(0, topic_num)
	
    for i = 1, topic_num do
        local topic = resp:string()
        local partition_num = resp:int32()
		core.log.info(topic,' -- ',partition_num)
        ret[topic] = {}

        for j = 1, partition_num do
            local partition = resp:int32()

            if api_version == API_VERSION_V0 or api_version == API_VERSION_V1 then
                ret[topic][partition] = {
                    errcode = resp:int16(),
                    offset = resp:int64(),
                }
			end
        end
    end

    return ret
end

local function _send(self)
	
    for i = 1, #self.broker_list do
        local host, port = self.broker_list[i].host, self.broker_list[i].port
        local bk = broker:new(host, port, self.socket_config)
		
		local resp,err = bk:send_receive(offset_encode(self))
		if not resp then
			ngx_log(INFO, "broker fetch offset failed, err:", err, ' -- ', host, ':', port)
		else
			local ret = offset_decode(resp)
			core.log.info(core.cjson.encode(ret))
			for topic,partitions in pairs(ret) do
				if self.topics[topic] then
					for partition,data in pairs(partitions) do
						self.topics[topic][partition] = data.offset
					end
				end
			end
		end
		
		local req = fetch_encode(self)
		
        local resp, err = bk:send_receive(req)
        if not resp then
            ngx_log(INFO, "broker fetch message failed, err:", err, ' -- ', host, ':', port)
        else
            return fetch_decode(resp),true
        end
    end
	
	return nil,false
end

function _M.new(self, broker_list, topic, group, consumer_config)
    local opts = consumer_config or {}
    local cli = client:new(broker_list)
    local c = setmetatable({
        client = cli,
		correlation_id = 1,
		broker_list = broker_list,
        request_timeout = opts.request_timeout or 2000,
        retry_backoff = opts.retry_backoff or 100,   -- ms
        max_retry = opts.max_retry or 3,
        required_acks = opts.required_acks or 1,
        partitioner = opts.partitioner or default_partitioner,
        error_handle = opts.error_handle,
        api_version = opts.api_version or API_VERSION_V0,
        socket_config = cli.socket_config,
    }, mt)
	
	c.topic_num = 1
	c.topics = {}
	c.topics[topic] = {}
	c.topics[topic][choose_partition(c,topic,group)] = 0
	
    return c
end

function _M.pull(self)
    local data,ok = _send(self)
    if not ok then
        return nil, 'read null'
    end

    return data
end


return _M
