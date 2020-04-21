--[[
与客户端之间的消息头定义
本文件修改后，需重启服务才能生效
tcp协议需要==>
return {
	size = 8,
	get = function(data) --根据data生成head对象，head对象中必须包含size属性 
	end,
	attr_size_name = 'MessageSize' --head对象中size属性的属性名
	tostring = function(data) end
	make = function(channel,command,entitytype,entityid,datasize) end --根据参数构建消息头
	parse = function(head) return channel,command,entitytype,entityid end
}
websocket协议需要==>
return {
	make = function(channel,command,entitytype,entityid,datasize) end --根据参数构建消息头
	parse = function(head) return channel,command,entitytype,entityid end
}
--]]

--websocket --> 字节流格式版本
---[[
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift

local ffi = core.ffi

local msgcheck = 0x026	--检验

local _check = function(head)
	local check = band(bor(bor(msgcheck , band(head.MessageSize , 0x0ffff)) , band(head.MessageOpt , 0x0ffff)) , bor(band(head.MessageSCmd , 0x0ffff),band(head.MessageUid , 0x0ffff)))
	return band(check , 0x0ff)
end

ffi.cdef[[
	#pragma pack (1)
	//消息结构--头部
	typedef struct STR_MSG_HEAD     
	{
		short int		HeadPad     ;       //消息头的标志				2
		short int		MessageOpt  ;       //操作类型					2	0本服处理 1BY-uid 2BY-Clubid 3BY-Deskid 4BY-(Gameid,Gareaid)
		short int		MessageFree ;       //预留2字节 字节对齐		2
		short int       MessageSize ;       //消息内容指令长度			2
		short int       MessageCmd  ;       //消息指令号				2
		short int       MessageSCmd ;       //消息子指令号				2
		int				MessageUid  ;       //用户数字ID				4
		int             MessageToken;       //用户令牌					4
		int             MessageKey	;		//消息负载均衡的key			4	根据功能 可取 uid  deskid  clubid 等
		short int       MessageFrom ;       //发起服务器编号			2
		short int       MessageTo	;		//目标服务器编号			2	无明确对象时 填0
		int             MessageCbk	;		//callbaclID做异步回调用	4	发给客户端消息 直接返回 服务器之间根据此值来进行回调
		short int       MessageCheck;       //消息校验位				2
		short int       MessageEnd	;       //消息头结束标识位			2
	} client_msg_head;
	#pragma pack()
]]

local msg_head_ctype = ffi.typeof('client_msg_head')
local size = ffi.sizeof('client_msg_head')

local _M = {}

--消息头大小
_M.size = size
--消息体大小在头中的属性名
_M.attr_size_name = 'MessageSize'

--获取一个消息头
_M.get = function(data)
	if #data < size then return nil,'the data length error' end
	local head = msg_head_ctype()
	ffi.copy(head,data or '000000000000000000000000000000000000000',size)
	if not data then
	end
	return head,size
end

_M.get_check = _check
--检查消息头是否合法
_M.check = function(head)
	local ck = _check(head)
	return ck == head.MessageCheck
end

--将消息头转换为字符串
_M.tostring = function(head)
	return ffi.string(head,size)
end

--根据参数构建一个消息头
_M.make = function(channel,command,entitytype,entityid,datasize)
	local head = msg_head_ctype()
	
	head.MessageCmd = channel
	head.MessageSCmd = command
	head.MessageUid = entityid
	head.MessageSize = datasize
	
	head.HeadPad = 0
	head.MessageEnd = 0
	head.MessageCheck = _check(head)
	
	return head
end

--解析出ms需要的参数
_M.parse = function(head)
	return head.MessageCmd,head.MessageSCmd,head.MessageOpt,head.MessageUid
end

return _M
--]]