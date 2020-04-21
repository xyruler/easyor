
local librdkafka = require 'resty.rdkafka.librdkafka'
local KafkaConfig = require 'resty.rdkafka.config'
local KafkaTopic = require 'resty.rdkafka.topic'
local KafkaTopicConfig = require 'resty.rdkafka.topic_config'
local ffi = require 'ffi'
local error = core.log.error

local DEFAULT_DESTROY_TIMEOUT_MS = 3000

local RD_KAFKA_PARTITION_UA = -1

local KafkaConsumer = {}
KafkaConsumer.__index = KafkaConsumer

function KafkaConsumer.create(kafka_config, destroy_timeout_ms)
    local config = nil
    if kafka_config ~= nil then
        config = KafkaConfig.create(kafka_config).kafka_conf_
        ffi.gc(config, nil)
    end
	
	local topic_conf = KafkaTopicConfig.create()
	topic_conf['auto.offset.reset'] = 'latest'
	
	librdkafka.rd_kafka_conf_set_default_topic_conf(config,topic_conf.topic_conf_)

    local ERRLEN = 512
    local errbuf = ffi.new("char[?]", ERRLEN) -- cdata objects are garbage collected
    local kafka = librdkafka.rd_kafka_new(librdkafka.RD_KAFKA_CONSUMER, config, errbuf, ERRLEN)

    if kafka == nil then
        error(ffi.string(errbuf))
		return nil
    end

    local consumer = {kafka_ = kafka}
	
	librdkafka.rd_kafka_poll_set_consumer(consumer.kafka_)
	
    setmetatable(consumer, KafkaConsumer)
    --ffi.gc(consumer.kafka_, function (...)
	--	local err = librdkafka.rd_kafka_consumer_close(consumer.kafka_)
	--	if err then
	--		core.log.info('failed to close consumer:',librdkafka.rd_kafka_err2str(err))
	--	else
	--		core.log.info('consumer closed')
	--	end
	--	if consumer.topics_ then
	--		librdkafka.rd_kafka_topic_partition_list_destroy(consumer.topics_)
	--	end
    --    librdkafka.rd_kafka_destroy(...)
    --    librdkafka.rd_kafka_wait_destroyed(destroy_timeout_ms or DEFAULT_DESTROY_TIMEOUT_MS)
    --    end
    --)

    return consumer
end

function KafkaConsumer:brokers_add(broker_list)
    assert(self.kafka_ ~= nil)
    return librdkafka.rd_kafka_brokers_add(self.kafka_, broker_list)
end

function KafkaConsumer:subscribe(topic_list)
	assert(self.kafka_ ~= nil)
	if self.topics_ then
		librdkafka.rd_kafka_topic_partition_list_destroy(self.topics_)
	end
    self.topics_ = librdkafka.rd_kafka_topic_partition_list_new(#topic_list)
	for _,v in ipairs(topic_list) do
		librdkafka.rd_kafka_topic_partition_list_add(self.topics_,v,RD_KAFKA_PARTITION_UA)
	end
	local err = librdkafka.rd_kafka_subscribe(self.kafka_,self.topics_)
	if err then 
		core.log.error('failed to start consuming topics: ',librdkafka.rd_kafka_err2str(err))
		return false
	end
	
	return true
end

function KafkaConsumer:poll(timeout)
    if not self.kafka_ or not self.topics_ then return nil,nil end
	
	local message = librdkafka.rd_kafka_consumer_poll(self.kafka_, timeout or 1000)
	
	if not message or message == ngx.NULL then return nil,nil end
	if message.err ~= librdkafka.RD_KAFKA_RESP_ERR_NO_ERROR then
		--core.log.info('consume error : ',ffi.string(librdkafka.rd_kafka_err2str(message.err)))
		librdkafka.rd_kafka_message_destroy(message)
		return nil,nil
	end
	
	local topic = ffi.string(librdkafka.rd_kafka_topic_name(message.rkt))
	local data = ffi.string(message.payload)
	
	librdkafka.rd_kafka_message_destroy(message)
	return data,topic
end

return KafkaConsumer
