--[[
本文件修改后，需重启服务才能生效
本模块中，不能直接执行require语句
--]]

local _M = {}
_M.debug = true		--调试状态，生产时请设置为false

-------------------------
--服务配置
--是否为单一进程服务
_M.singleton_work = true
--进程数量
_M.worker_num = 1
--日志等级
_M.loglevel = 'debug'
--是否开启access日志
_M.access_log_on = true

--服务使用的协议
--_M.use_tcp = true
--_M.use_udp = true
_M.use_http  = true
--端口设置
--_M.tcp_ports = {8080}
--_M.udp_ports = {8081}
_M.http_ports = {80}
--是否允许跨域
_M.http_allow_cross_domain = true
--最大的计时器数量
_M.max_running_timers = 2560
---------------------------
--phase开关
--是否重载相应的处理过程，重载方法在app.lua中定义
_M.phase = {}
_M.phase.preread = false
_M.phase.rewrite = false
_M.phase.access = false
_M.phase.header_filter = false
_M.phase.body_filter = false
_M.phase.log = false

---------------------------
--路由配置
--根目录设置
_M.route_root = 'api'

--[[配置特殊的路由
_M.http_locations = {
	wxpaycallback = {
		mode = '=',						--路径匹配规则，参考nginx
		path = '/weixin/pay/callback',	--访问路径
		real_path = 'api/pay/weixin',	--内部路径
		allow = { 						--允许访问的ip列表,可选
			'wx_ip_1',
			'wx_ip_2',
		}，
		add_headers = {					--添加头数据,可炫
			"'Access-Control-Allow-Origin' '*'",
			"'Access-Control-Allow-Credentials' 'true'",
			"'Access-Control-Allow-Methods' 'GET'",
			"'Access-Control-Allow-Methods' 'POST'",
			"'Access-Control-Allow-Headers' 'Content-Type,XFILENAME,XFILECATEGORY,XFILESIZE'",
		},		
	},
	zfbpaycallback = {
		mode = '^~',
		path = '/zfb/pay/(.*)',
		real_path = 'api/pay/zfb/$1',	--可以使用变量，参考nginx
	},
}
--]]

----------------------------
--缓存配置
_M.caches = {
	my_simple_cache = {
		share_dict_size = '10m',	--共享内存大小
		lru_size = 10000,			--worker中缓存的最大对象个数
		ttl = 3600,					--缓存有效时间，单位秒
		neg_ttl = 60,				--缓存中未命中对象有效时间，单位秒
		--[[缓存锁参数
		resty_lock_opts = {
			timeout = 5,
			exptime = 30,
			step = 0.001,
			ratio = 2,
			max_step = 0.5,
		},
		--]]
		--l1_serializer = function(value) return value,err end,	--值序列化函数,从sharedict中取出后存入lua内存时调用 --可以是模块路径
	},
	my_cache_bind_mysql = {
		share_dict_size = '10m',	--共享内存大小
		lru_size = 10000,			--worker中缓存的最大对象个数
		ttl = 3600,					--缓存有效时间，单位秒
		neg_ttl = 60,				--缓存中未命中对象有效时间，单位秒
		--[[缓存锁参数
		resty_lock_opts = {
			timeout = 5,
			exptime = 30,
			step = 0.001,
			ratio = 2,
			max_step = 0.5,
		},
		--]]
		--l1_serializer = function(value) return value,err end,	--值序列化函数,从sharedict中取出后存入lua内存时调用 --可以是模块路径
		
		--数据库绑定配置
		--只可绑定一个数据库
		--绑定数据库后，缓存的key值应与配置中的keys对应，用:分割
		--如：keys = {'uid','areaid'}
		--缓存中key应为 uid:areaid 如： 100023:308
		database = {				--绑定数据库
			type = 'mysql',			--数据库类型，支持-mysql,user
			--以下配置跟type相关
			--mysql配置
			--必需部分
			master = 'example_mysql',	--读写库配置名，配置数据在_M.db中定义
			slave = 'example_mysql',	--只读库配置名，默认为master配置
			table = 'user_info',	--表名
			get_table_name = function(key)	--根据key获取表名，当该函数被定义时，‘table’属性无效 --可以是模块路径
				local idx = tonumber(key) % 16
				return 'user_info_' .. idx
			end,
			keys = {				--唯一索引，可以是多个字段
				'uid',
			},
			--可选部分
			auto_incr = 'uid',		--自增字段名，插入新数据时自动生成
			--缓存的值字段列表
			--未设置时，将缓存所有字段数据
			--设置后，保存数据时，将只获取和保存已设置的字段数据
			value_keys = {			
				'name','nick','tel'
			},
		},
	},
	my_cache_bind_user = {
		share_dict_size = '10m',	--共享内存大小
		lru_size = 10000,			--worker中缓存的最大对象个数
		ttl = 3600,					--缓存有效时间，单位秒
		neg_ttl = 60,				--缓存中未命中对象有效时间，单位秒
		--[[缓存锁参数
		resty_lock_opts = {
			timeout = 5,
			exptime = 30,
			step = 0.001,
			ratio = 2,
			max_step = 0.5,
		},
		--]]
		--l1_serializer = function(value) return value,err end,	--值序列化函数,从sharedict中取出后存入lua内存时调用 --可以是模块路径
		
		--当缓存中没有数据时，获取数据的方法
		--ctx:配置数据
		--key:get方法传入的key值
		get_from_db = function(ctx,key)	--可以是模块路径
			return value,err
		end,
		--当有数据更改时，保存数据的方法
		--ctx:配置数据
		--key:set方法传入的key值
		--value:set方法传入的value值
		--bnew:是否为新增key
		save_to_db = function(ctx,key,value,bnew)	--可以是模块路径
			return newkey,value,err
		end,
		database = {				--绑定数据库
			type = 'user',			--数据库类型，支持-mysql,redis,user
			--user配置
			--自定义数据库，读写由get_from_db，save_to_db方法承担
			--配置数据将由参数ctx传入
		},
	},
}

----------------------------
--DB配置
_M.db = {}
--Mysql配置
_M.db.example_mysql = {
	type = 'mysql',
	host = '127.0.0.1',
	port = 3306,
	user = 'root',
	password = 'xxxxx',
	database = 'xxxx',
	--concurrency = 4,		--最大读写并发数,默认100
}

----------------------------
--Redis配置
_M.db.example_redis = {
	type = 'redis',
	host = '127.0.0.1',
	port = 6379,
	--password = 'Laiyx@Zhuoxun.com',
	db_index = 0,
	--concurrency = 1000,	--最大读写并发数,默认1000
}

----------------------------
--Kafka配置
_M.kafka = {}

--Kafka Producer 配置
_M.kafka.producer = {
	type = 'producer',		
	broker_list = {
		{host = '127.0.0.1', port = 9092},
	},
	config = {
	},
	topic_config = {
		default = {
		},
		--topic_name = {},
	},
}

--Kafka Consumer 配置
_M.kafka.consumer = {
	type = 'consumer',
	--在哪个工作进程中启动，默认第一个,
	--一个worker里只能有一个consumer
	--当这个worker里启动了consumer，将不能再处理其他的消息
	worker_id = 0,
	broker_list = {
		{host = '127.0.0.1', port = 9092},
	},
	group = 'mygroup',	--groupid
	config = {
	},
	topic_list = {		--监听主题列表
		'topic1',
		'topic2',
	},
	dofun = 'api.dofun',	--消息处理函数
}

--

return _M