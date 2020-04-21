--[[
db数据加载
目前支持mysql redis
--]]
local config = require 'config'
local kafka_config = require 'resty.rdkafka.config'
local kafka_topic_config = require 'resty.rdkafka.topic_config'
local kafka_topic = require 'resty.rdkafka.topic'
local kafka_producer = require 'resty.rdkafka.producer'
local kafka_consumer = require 'resty.rdkafka.consumer'

local log_err = core.log.error

local _M = {}

for name,opts in pairs(config.kafka or {}) do
	if not opts.broker_list then
		log_err('Kafka config has wrong parameters. name = ',name)
	else
		if opts.type == 'producer' then
			local c = kafka_config.create()
			c['statistics.interval.ms'] = 100
			for k,v in pairs(opts.config or {}) do
				c[k] = v
			end
			
			local p = kafka_producer.create(c)
			p.broker_list = opts.broker_list
			p.topics = {}
			p.type = 'producer'
			p.send = function(self,topic,message)
				if not self.init then
					for i,v in ipairs(self.broker_list) do
						self:brokers_add(v.host .. ':' .. v.port)
					end
					self.init = true
				end
				local tp = self.topics[topic]
				if not tp then
					local tpc = kafka_topic_config.create()
					tpc["auto.commit.enable"] = "true"
					if opts.topic_config then
						for k,v in pairs(opts.topic_config.default or {}) do
							tpc[k] = v
						end
						for k,v in pairs(opts.topic_config[topic] or {}) do
							tpc[k] = v
						end
					end
					
					tp = kafka_topic.create(self,topic,tpc)
					self.topics[topic] = tp
				end
				self.produce(self,tp,-1,message)
			end
			
			_M[name] = p
		elseif opts.type == 'consumer' and opts.worker_id == ngx.worker.id() then
			if not opts.group or not opts.topic_list or not opts.dofun then 
				log_err('Kafka Consumer has wrong parameters. name = ',name)
			else
				local ok, fun = pcall(require, opts.dofun)
				if ok and type(fun) == 'function' then
					local c = kafka_config.create()
					c['internal.termination.signal'] = 23 --SIGIO
					for k,v in pairs(opts.config or {}) do
						c[k] = v
					end
					c['group.id'] = opts.group
					
					local cc = kafka_consumer.create(c)
					cc.type = 'consumer'
					cc.broker_list = opts.broker_list
					cc.topic_list = opts.topic_list
					cc.isrun = false
					cc.dofun = fun
					cc.run = function(self,interval)
						if not self.init then
							for i,v in ipairs(self.broker_list) do
								self:brokers_add(v.host .. ':' .. v.port)
							end
							self:subscribe(self.topic_list)
							self.init = true
						end
						self.isrun = true
						while self.isrun do
							local msg,topic = self:poll(interval or 3000)
							ngx.update_time()
							if msg then
								self.dofun(msg,topic)
							end
						end
					end
					cc.stop = function(self)
						self.isrun = false
					end
					
					_M[name] = cc
				else
					log_err('Kafka Consumer dofun is not a function. name = ',name)
				end
			end
		end
	end
end

return _M