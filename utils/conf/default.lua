--[[
nginx默认配置
--]]

local _M = {}

--[[debug模式，默认关闭
_M.debug = true
--]]

--[[以指定用户启动 默认为无
_M.user = 'www www'
--]]

--[[进程数量，默认为系统cpu核心数量
_M.worker_num = 1
--]]

--[[在高并发情况下, 通过设置cpu粘性来降低由于多CPU核切换造成的寄存器等现场重建带来的性能损耗
_M.worker_cpu_affinity = 'auto'
--]]

--[[设置操作系统最大限制 65535
_M.worker_rlimit_nofile = 65535
--]]

--[[日志设置
_M.loglevel = 'info',	--日志等级，默认为'info'(在debug模式下，锁定为'debug')
--]]

--[[事件触发模式，默认为 epoll
_M.eventtype = 'epoll'
--]]

--[[单进程允许最大连接数，默认为系统最大可打开文件数
_M.worker_connections = 20480
--]]

---[[立即接受所有连接放到监听队列中, 在获得新连接的通知时尽可能多的接受连接
_M.multi_accept = true
--]]

--[[优化同一时刻只有一个请求而避免多个睡眠进程被唤醒的设置，on为防止被同时唤醒，默认为off
_M.accept_mutex = true
--]]

--[[打开core文件并设置大小
_M.open_core = '50M' 
--]]

--[[当安全结束一个worker进程时，会停止对worker进程分配新连接，并等待他处理完当前的任务后再退出，如果设置了超时时间，超时后nginx会强制关闭worker进程的连接。
_M.worker_shutdown_timeout = 10
--]]

---[[日志格式
_M.logformat = {
    --$upstream_cache_status 记录的是缓存命中率
 	main = [=['$remote_addr - $remote_user [$time_local] "$request" '
        '$status $body_bytes_sent "$http_referer" '
        '"$http_user_agent" "$http_x_forwarded_for"' 
        '"$upstream_cache_status" "$request_body"';
	]=],
--	logstash_json = [=['{"@timestamp":"$time_iso8601",'
--        '"host":"$server_addr",'
--        '"clientip":"$remote_addr",'
--        '"size":$body_bytes_sent,'
--        '"responsetime":$request_time,'
--        '"upstreamtime":"$upstream_response_time",'
--        '"upstreamhost":"$upstream_addr",'
--        '"http_host":"$host",'
--        '"url":"$uri",'
--        '"domain":"$host",'
--        '"xff":"$http_x_forwarded_for",'
--        '"referer":"$http_referer",'
--        '"agent":"$http_user_agent",'
--        '"status":"$status"}';
--	]=],
}
--]]

--[[数据传输优化配置
_M.trans = {
	sendfile = 'on',	--开启高效文件传输模式 (如果用来进行下载等应用磁盘IO重负载应用, 可设置为off, 以平衡磁盘与网络I/O处理速度, 降低系统的负载.)
	tcp_nopush = 'on',	--设置一个数据包里发送所有头文件, 而不一个接一个的发送. 
	tcp_nodelay = 'on',	--不要缓存数据, 而是一段一段的发送(当需要及时发送数据时, 就应该给应用设置这个属性, 这样发送一小块数据信息时就可以立即得到返回值.)
}
--]]

--[[超时设置
_M.timeout = {
	keepalive_timeout = '120s',	--长连接超时时间, 秒 (长连接请求大量小文件的时候, 可以减少重建连接的开销, 但假如有大文件上传, 65s 内没上传完成会导致失败. 如果设置时间过长, 用户又多,  长时间保持连接会占用大量资源. )
	send_timeout = '60s',			--响应客户端超时时间, 秒
	--client_header_timeout = '60s',
	client_body_timeout = '60s',
}
--]]

--[[ssl设置
_M.ssl = {
	ssl_session_cache = 'shared:SSL:10m',	--设置ssl/tls会话缓存的类型和大小. 如果设置了这个参数一般是shared, buildin可能会参数内存碎片, 默认是 none, 和 off 差不多, 停用缓存. 如 shared:SSL:10m 表示我所有的 nginx 工作进程共享 ssl 会话缓存, 官网介绍说 1M 可以存放约 4000 个 sessions. 详细参考 serverfault 上的问答 ssl_session_cache.
	ssl_session_timeout = '30m',			--客户端可以重用会话缓存中 ssl 参数的过期时间, 内网系统默认 5分钟 太短了, 可以设成 30m 即 30分钟 甚至 4h
	
	ssl_certificate = '../SSL/ittest.pem',
	ssl_certificate_key = '../SSL/ittest.key',
	ssl_protocols = 'SSLv3 TLSv1 TLSv1.1 TLSv1.2',
	ssl_ciphers = 'ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP',
	ssl_prefer_server_ciphers = 'on',
}
--]]

--[[client缓存设置
_M.client_buffer = {
	client_body_buffer_size = '16k',	--请求的缓冲区大小
	client_max_body_size = '10m',		--允许客户端请求的最大单文件字节数
	client_body_in_single_buffer = 'on',--将请求体完整的存储在一块连续的内存中
	client_header_buffer_size = '128k',	--请求头缓冲区
	large_client_header_buffers = '8 64k',--大型客户端请求头缓冲区
}
--]]

--[[fastcgi设置
_M.fastcgi = {
	fastcgi_buffers = '256 16k',		--指定本地需要用多少和多大的缓冲区来缓冲FastCGI的应答请求. 一般这个值应该为站点中PHP脚本所产生的页面大小的中间值, 如果站点大部分脚本所产生的页面大小为256KB, 那么可以把这个值设置为"16 16k", "4 64k"等. 
	fastcgi_buffer_size = '128k',		--指定读取FastCGI应答第一部分需要用多大的缓冲区, 表示将使用1个64KB的缓冲区读取应答的第一部分(应答头)
	fastcgi_connect_timeout = '10s',	--指定连接到后端FastCGI的超时时间.
	fastcgi_send_timeout = '120s',		--指定向FastCGI传送请求的超时时间, 这个值是已经完成两次握手后向FastCGI传送请求的超时时间.
	fastcgi_read_timeout = '120s',		--指定接收FastCGI应答请求的超时时间, 这个值是已经完成两次握手后接收FastCGI应答的超时时间.
	fastcgi_busy_buffers_size = '256k',	--系统忙时缓冲区大小
	fastcgi_temp_file_write_size = '256k',--写入缓存文件时使用多大的数据块
}
--]]

--[[gzip设置
_M.gzip = {	--开启gzip压缩输出, 减少网络传输.
	gzip_min_length = '1k', 	--设置允许压缩的页面最小字节数, 页面字节数从 header 头得 content-length 中进行获取. 默认值是20. 建议设置成大于1k的字节数, 小于1k可能会越压越大. 
	gzip_buffers = '4 16k', 	--设置系统获取几个单位的缓存用于存储 gzip 的压缩结果数据流. 4 16k 代表以 16k 为单位, 安装原始数据大小以 16k 为单位的4倍申请内存.
	gzip_http_version = '1.0', 	--用于识别 http 协议的版本, 早期的浏览器不支持 Gzip 压缩, 用户就会看到乱码, 所以为了支持前期版本加上了这个选项, 如果你用了 Nginx 的反向代理并期望也启用 Gzip 压缩的话, 由于末端通信是 http/1.0, 故请设置为 1.0.
	gzip_comp_level = '4', 		--gzip 压缩比, 1压缩比最小处理速度最快, 9压缩比最大但处理速度最慢 (传输快但比较消耗cpu)
	gzip_types = 'text/html text/plain text/css text/javascript application/json application/javascript application/x-javascript application/xml', --指定压缩类型
	gzip_vary = 'on', 			--和http头有关系, 会在响应头加个 Vary: Accept-Encoding , 可以让前端的缓存服务器缓存经过 gzip 压缩的页面, 例如, 用 Squid 缓存经过 Nginx 压缩的数据
	gzip_disable = '"MSIE [1-6]\\."', --配置禁用gzip条件, 支持正则. 此处表示ie6及以下不启用gzip(因为ie低版本不支持)
	--[=[
		Nginx作为反向代理的时候启用, 决定开启或者关闭后端服务器返回的结果是否压缩, 匹配的前提是后端服务器必须要返回包含 "Via" 的 header 头
		expired -  启用压缩, 如果header头中包含 "Expires" 头信息
		no-cache - 启用压缩, 如果header头中包含 "Cache-Control:no-cache" 头信息
		no-store - 启用压缩, 如果header头中包含 "Cache-Control:no-store" 头信息
		private -  启用压缩, 如果header头中包含 "Cache-Control:private" 头信息
		no_last_modified - 启用压缩, 如果header头中不包含 "Last-Modified" 头信息
		no_etag -  启用压缩, 如果header头中不包含 "ETag" 头信息
		auth -     启用压缩, 如果header头中包含 "Authorization" 头信息
		any -      无条件启用压缩
	]=]
	gzip_proxied = 'gzip_proxied expired no-cache no-store private auth', 
}
--]]

---[[ngx_lua配置
_M.lua = {
	--lua_ssl_verify_depth = 5,				--
	--lua_socket_log_errors = 'off',			--
	--lua_http10_buffering = 'off',			--
	--lua_regex_match_limit = '100000',		--
	--lua_regex_cache_max_entries = '8192',	--
	--lua_max_running_timers = 256,
}
--]]

---[[resolver配置
_M.resolver = {
	list = {
		'8.8.8.8',
		
	},
--	ipv6 = false,	--
	timeout = 5,	--
}
--]]

--[[代理参数设置
_M.proxy = {
	proxy_connect_timeout = '75',		--nginx 跟后端服务器连接超时时间(代理连接超时)
	proxy_send_timeout = '75',			--
	proxy_read_timeout = '75',			--连接成功后, 与后端服务器两个成功的响应操作之间超时时间(代理接收超时)
	proxy_buffer_size = '4k',			--代理服务器 (nginx) 从后端 realserver 读取并保存用户头信息的缓冲区大小, 默认与 proxy_buffers 大小相同, 其实可以将这个指令值设的小一点
	proxy_buffers = '4 32k',			--proxy_buffers缓冲区, nginx针对单个连接缓存来自后端realserver的响应, 网页平均在32k以下的话, 这样设置
	proxy_busy_buffers_size = '64k',	--高负荷下缓冲大小(proxy_buffers*2)
	--proxy_max_temp_file_size = '1024M',	--当 proxy_buffers 放不下后端服务器的响应内容时, 会将一部分保存到硬盘的临时文件中, 这个值用来设置最大临时文件大小, 默认1024M, 它与 proxy_cache 没有关系. 大于这个值, 将从 upstream 服务器传回. 设置为0禁用.
	proxy_temp_file_write_size = '64k',	--当缓存被代理的服务器响应到临时文件时, 这个选项限制每次写临时文件的大小.
	proxy_temp_path = '/usr/local/nginx/proxy_temp 1 2',	--临时文件路径 (可在编译时指定目录)
	--[=[
		设置缓存目录, 目录里的文件名是 cache_key 的MD5值.
		levels=1:2 keys_zone=cache_one:50m 表示采用2级目录结构, Web缓存区名称为cache_one, 内存缓存空间大小为100MB, 这个缓冲zone可以被多次使用.
		inactive=2d max_size=2g 表示2天没有被访问的内容自动清除, 硬盘最大缓存空间为 2GB, 超过这个大学将清除最近最少使用的数据. 
	--]=]
	--proxy_cache_path = '/usr/local/nginx-1.6/proxy_cache levels=1:2 keys_zone=cache_one:100m inactive=2d max_size=2g'
}
--]]

--[[负载均衡设置
_M.upstream = {
	backend = {	--组名
		servers = { --服务器列表
			'192.168.10.100:8080 max_fails=2 fail_timeout=30s',
			'192.168.10.101:8080 max_fails=2 fail_timeout=30s',
		},
		mode = 'sticky',--负责均衡模式，(sticky:启动 nginx-sticky-module 模块, (不能与 ip_hash 同时使用))
		keepalive = 320,
	},
	
	backend2 = {	--组名
		servers = { --服务器列表
			'172.29.88.226:8080 weight=1 backup',
			'192.168.10.102',
		},
		mode = 'ip_hash',--负责均衡模式，(sticky:启动 nginx-sticky-module 模块, (不能与 ip_hash 同时使用))
		balancer_by_lua_file = 'balancer.backend2' --使用lua脚本进行负载均衡
	},
	
}
--]]

--[[共享字典列表
_M.share_dicts = {
	my_cache = '10m',
	my_cache2 = '100m',
}
--]]

---[[http访问日志 access_log
_M.access_log = {
	format = 'main',	--access_log 日志格式
	buffer = '32k',		--access_log 缓存大小
}
--]]

--open_file_cache
--server_tokens
--more_set_headers
--real_ip_header
--set_real_ip_from

--[=======[stream设置
_M.stream = {
	tcp = {
		'8080',
	},
	udp = {
		'8080',
	},
}
--]=======]

--[=======[http设置
_M.http = {}
--_M.http.mustusehttps = true

---[[http服务设置
_M.http.server = {
	--[=[
	listen = {	--默认为80
		'8080',
		'8080 ssl http2',
		'127.0.0.1:8080',
		'[::]:8080',
		'[::]:8080 ssl http2',
	},
	--]=]
	server_name = 'www.mysite.com',
	---[=[
	location_main = {
		--[==[
		allow = {
			'192.168.1.0/24',
			'192.168.2.22',
		},
		--]==]
		--[==[
		add_headers = {
			"'Access-Control-Allow-Origin' '*'",
			"'Access-Control-Allow-Credentials' 'true'",
			"'Access-Control-Allow-Methods' 'GET'",
			"'Access-Control-Allow-Methods' 'POST'",
			"'Access-Control-Allow-Headers' 'Content-Type,XFILENAME,XFILECATEGORY,XFILESIZE'",
		},
		--]==]
	},
	--]=]
	--[=[
	location_file = {
		--root = '',
		expires = '7d',
		--exts = 'gif|jpg|jpeg|bmp|png|ico|txt|js|css|html|htm',
		--[==[
		allow = {
			'192.168.1.0/24',
			'192.168.2.22',
		},
		--]==]
		--[==[
		add_headers = {
			"'Access-Control-Allow-Origin' '*'",
			"'Access-Control-Allow-Credentials' 'true'",
			"'Access-Control-Allow-Methods' 'GET'",
			"'Access-Control-Allow-Methods' 'POST'",
			"'Access-Control-Allow-Headers' 'Content-Type,XFILENAME,XFILECATEGORY,XFILESIZE'",
		},
		--]==]
	},
	--]=]
	--[=[
	locations = {
		--[==[
		trans1 = {
			mode = '=',
			path = '/xxxxx/yyyy',
			real_path = 'api/ccc/ddd',
			---[===[
			allow = {
				'192.168.1.0/24',
				'192.168.2.22',
			},
			--]===]
		},
		--]==]
	},
	--]=]
}
--]]
--]=======]

return _M