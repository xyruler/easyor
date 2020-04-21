--[[
redis对象
--]]
local ngx = ngx
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
local semaphore = require "ngx.semaphore"
local sleep = ngx.sleep

local redis_c = require "resty.redis"

local pool_max_idle_time = 50000 --毫秒  
local pool_size = 500 --连接池大小  
local timeout = 5000
local get_address = require 'core.dns.getaddress'
local s_len = string.len

--[[调用示例代码：
local redis = require "resty.redis_iresty"
local red = redis:new()

local ok, err = red:set("dog", "an animal")
if not ok then
    ngx.say("failed to set dog: ", err)
    return
end

ngx.say("set result: ", ok)
]]
--
local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function(narr, nrec) return {} end
end

local _M = new_tab(0, 155)
_M._VERSION = '0.01'

local commands = {
    "append",            "auth",            "bgrewriteaof",
    "bgsave",            "bitcount",        "bitop",
    "blpop",            "brpop",
    "brpoplpush",        "client",            "config",
    "dbsize",
    "debug",            "decr",            "decrby",
    "del",            "discard",        "dump",
    "echo",
    "eval",            "exec",            "exists",
    "expire",            "expireat",        "flushall",
    "flushdb",        "get",            "getbit",
    "getrange",        "getset",            "hdel",
    "hexists",        "hget",            "hgetall",
    "hincrby",        "hincrbyfloat",    "hkeys",
    "hlen",
    "hmget",            "hmset",    "hscan",
    "hset",
    "hsetnx",            "hvals",            "incr",
    "incrby",            "incrbyfloat",    "info",
    "keys",
    "lastsave",        "lindex",            "linsert",
    "llen",            "lpop",            "lpush",
    "lpushx",            "lrange",            "lrem",
    "lset",            "ltrim",            "mget",
    "migrate",
    "monitor",        "move",            "mset",
    "msetnx",            "multi",            "object",
    "persist",        "pexpire",        "pexpireat",
    "ping",            "psetex",            "psubscribe",
    "pttl",
    "publish",
    --[[ "punsubscribe", ]]
    "pubsub",
    "quit",
    "randomkey",        "rename",            "renamenx",
    "restore",
    "rpop",            "rpoplpush",        "rpush",
    "rpushx",            "sadd",            "save",
    "scan",            "scard",            "script",
    "sdiff",            "sdiffstore",
    "select",            "set",            "setbit",
    "setex",            "setnx",            "setrange",
    "shutdown",        "sinter",            "sinterstore",
    "sismember",        "slaveof",        "slowlog",
    "smembers",        "smove",            "sort",
    "spop",            "srandmember",    "srem",
    "sscan",
    "strlen",
    --[[ "subscribe",  ]]
    "sunion",
    "sunionstore",    "sync",            "time",
    "ttl",
    "type",
    --[[ "unsubscribe", ]]
    "unwatch",
    "watch",            "zadd",            "zcard",
    "zcount",            "zincrby",        "zinterstore",
    "zrange",            "zrangebyscore",    "zrank",
    "zrem",            "zremrangebyrank", "zremrangebyscore",
    "zrevrange",        "zrevrangebyscore", "zrevrank",
    "zscan",
    "zscore",            "zunionstore",    "evalsha"
}

local mt = { __index = _M }

local function is_redis_null(res)
    if type(res) == "table" then
        for k, v in pairs(res) do
            if v ~= ngx.null then
                return false
            end
        end
        return true
    elseif res == ngx.null then
        return true
    elseif res == nil then
        return true
    end

    return false
end

local function new_con(self)
	if self.inuse >= self.concurrency then
		while self.inuse >= self.concurrency do
			self.sema:wait(1)
		end
	end
	
	self.inuse = self.inuse + 1
	local redis, err = redis_c:new()
	
	return redis,err
end

local function release_con(self)
	
	self.inuse = self.inuse - 1
	self.sema:post(1)

end

-- change connect address as you need
function _M.connect_mod(self, redis)
    redis:set_timeout(self.timeout)
    self.host = get_address(self.host)
    local ok, err = redis:connect(self.host, self.port)
    if self.password and s_len(self.password) > 0 then
        local count, err = redis:get_reused_times()
        if count == 0 then ok, err = redis:auth(self.password) end
    end
    return ok, err
end

function _M.set_keepalive_mod(redis)
    -- put it into the connection pool of size 100, with 60 seconds max idle time
    return redis:set_keepalive(pool_max_idle_time, pool_size)
end

function _M.init_pipeline(self)
    self._reqs = {}
end

function _M.commit_pipeline(self)
    local reqs = self._reqs

    if nil == reqs or 0 == #reqs then
        return {}, "no pipeline"
    else
        self._reqs = nil
    end

    local redis, err = new_con(self) --redis_c:new()
    if not redis then
		release_con(self)
        return nil, err
    end

    local ok, err = self:connect_mod(redis)
    if not ok then
		release_con(self)
        return {}, err
    end

    redis:init_pipeline()
    for _, vals in ipairs(reqs) do
        local fun = redis[vals[1]]
        table.remove(vals, 1)
        fun(redis, unpack(vals))
    end

    local results, err = redis:commit_pipeline()
    if not results or err then
		release_con(self)
        return {}, err
    end

    if is_redis_null(results) then
        results = {}
        ngx.log(ngx.WARN, "is null")
    end
    -- table.remove (results , 1)
	self.set_keepalive_mod(redis)
 	release_con(self)

    for i, value in ipairs(results) do
        if is_redis_null(value) then
            results[i] = nil
        end
    end

    return results, err
end

function _M.subscribe(self, channel)
    local redis, err = new_con(self) --redis_c:new()
    if not redis then
		release_con(self)
        return nil, err
    end

    local ok, err = self:connect_mod(redis)
    if not ok or err then
		release_con(self)
        return nil, err
    end

    local res, err = redis:subscribe(channel)
    if not res then
		release_con(self)
        return nil, err
    end

    local function do_read_func(do_read)
        if do_read == nil or do_read == true then
            res, err = redis:read_reply()
            if not res then
                return nil, err
            end
            return res
        end

        redis:unsubscribe(channel)
        self.set_keepalive_mod(redis)
		release_con(self)
        return
    end

    return do_read_func
end

local function do_command(self, cmd, ...)
    if self._reqs then
        table.insert(self._reqs, { cmd, ... })
        return
    end

    local redis, err = new_con(self) --redis_c:new()
    if not redis then
		release_con(self)
        return nil, err
    end

    local ok, err = self:connect_mod(redis)
    if not ok or err then
		release_con(self)
        return nil, err
    end

    local fun = redis[cmd]
    local result, err = fun(redis, ...)
    if not result or err then
        -- ngx.log(ngx.ERR, "pipeline result:", result, " err:", err)
		release_con(self)
        return nil, err
    end

    if is_redis_null(result) then
        result = nil
    end

    self.set_keepalive_mod(redis)
	release_con(self)
    return result, err
end

function _M.new(self, opts)
    opts = opts or {}

    local timeout = (opts.timeout and opts.timeout * 1000) or timeout
    local db_index = opts.db_index or 0
    local host = opts.host or "127.0.0.1"
    local port = opts.port or 6379
    local password = opts.password or ""
	local concurrency = opts.concurrency or 1000

    for i = 1, #commands do
        local cmd = commands[i]
        _M[cmd] =        function(self, ...)
            return do_command(self, cmd, ...)
        end
    end

    return setmetatable({
        timeout = timeout,
        db_index = db_index,
        host = host,
        port = port,
        password = password,
        _reqs = nil,
		inuse = 0,
		concurrency = concurrency,
		sema = semaphore:new(),
    }, mt)
end

return _M