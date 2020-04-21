--[[
ms内部消息消息头
--]]
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift

local ffi = core.ffi
local cache = core.cache

local msgcheck = 0x026	--检验

local _check = function(head)
	local check = band(bor(bor(msgcheck , band(head.MessageSize , 0x0ffff)) , band(head.MessageSer , 0x0ffff)) , bor(band(head.MessageSCmd , 0x0ffff),band(head.MessageUid , 0x0ffff)))
	return band(check , 0x0ff)
end

ffi.cdef[[
	#pragma pack (1)
	//消息结构--头部
	typedef struct MS_MSG_HEAD
	{
		unsigned char	Opt;		//消息类型			2 0-广播消息 1-请求消息 2-回复消息 3-消息发送回执(发送失败时返回)
		unsigned char	ToChannel;	//目标服务频道ID	2 为广播消息时，表示消息主题
		unsigned char	To;			//目标服务器编号	2 无明确对象时 填0
		unsigned char	FromChannel;//发起服务频道ID	2
		unsigned char	From;		//发起服务器编号	2
		unsigned char	EntityType;	//消息操作对象类型	2
		unsigned short	Command;	//消息ID			2
		unsigned int	EntityId;	//消息操作对象ID	8 无明确对象是 填0 将用作负载均衡的key
		unsigned int	Cbk;		//回调ID			4 广播消息 填0
	} ms_message_head;
	#pragma pack()
]] 

local head_size = ffi.sizeof('ms_message_head')
local head_ctype = ffi.typeof('ms_message_head')

local _get = function(data)
	if data and #data < head_size then return nil,'the data length error' end
	
	local head = head_ctype()
	ffi.copy(head,data or '00000000000000000000000000',head_size)
	
	return head,head_size
end

local _M = {
	size = head_size,
	check = _check,
	get = _get,
}

return _M
