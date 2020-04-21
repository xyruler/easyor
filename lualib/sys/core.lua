--[[
系统各过程处理函数
--]]
sys = {}
sys.phase = {}

sys.phase.init 				= require 'sys.phase.init'
sys.phase.init_worker 		= require 'sys.phase.init_worker'
sys.phase.ssl_certificate 	= require 'sys.phase.ssl_certificate'
sys.phase.preread 			= require 'sys.phase.preread'
sys.phase.rewrite 			= require 'sys.phase.rewrite'
sys.phase.access 			= require 'sys.phase.access'
sys.phase.content 			= require 'sys.phase.content'	--content_for_stream
sys.phase.route 			= require 'sys.phase.route'		--content for http
sys.phase.balancer 			= require 'sys.phase.balancer'
sys.phase.header_filter 	= require 'sys.phase.header_filter'
sys.phase.body_filter 		= require 'sys.phase.body_filter'
sys.phase.log 				= require 'sys.phase.log'
sys.phase.ssl_session_fetch = require 'sys.phase.ssl_session_fetch'
sys.phase.ssl_session_store = require 'sys.phase.ssl_session_store'
