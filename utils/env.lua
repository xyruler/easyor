--[[
1、提供环境变量
2、提供文件操作方法
--]]

local _M = {}

--执行linux命令
local excute_cmd = function(cmd)
    local t = io.popen(cmd)
    local data = t:read("*all")
    t:close()
    return data
end

local trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--获取最后一个指定的字符
local find_last = function(s,pattern)
	local rs = s:reverse()
	local pos = rs:find(pattern)
	if not pos then return #s end
	return #s - pos + 1
end

--获取openresty安装路径
local get_openresty_path = function()
	local orpath = excute_cmd('which openresty 2>&1')
	if orpath:sub(1,1) ~= '/' then
		error('can not find the openresty, install failed.')
	end
	orpath = excute_cmd('readlink -f ' .. orpath)
	
	local p1,p2 = orpath:find('openresty')
	if p2 then
		return orpath:sub(1,p2)
	end
	
	--return orpath
end

--获取myor路径
local get_myor_path = function()
	local orpath = arg[0]
	local ls = excute_cmd('ls -l ' .. orpath)
	local lnk = ls:find('->')
	if lnk then
		orpath = ls:sub(lnk + 1,find_last(ls,'/') - 1)
		orpath = orpath:sub(orpath:find('/'), #orpath)
	else
		orpath = orpath:sub(1,find_last(orpath,'/') - 1)
	end
	
	return orpath
end

--获取当前工作路径
local get_worker_path = function()
	local p1 = arg[2] or ''
	if p1:sub(1, 1) == '/' then
		if p1:sub(#p1) == '/' then
			return p1:sub(1,#p1 - 1)
		else
			return p1
		end
	elseif #p1 > 0 then
		return _M.pwd .. '/' .. p1
	end
	
	return false
end

--获取文件夹名
local get_folder_name = function(path)
	if path:sub(#path) == '/' then
		path = path:sub(1,#path - 1)
	end
	return path:sub(find_last(path,'/') + 1)
end

--判定服务是否正在运行
local is_service_run = function(project)
	local runing = false
	local rs = excute_cmd('ps -ef|grep ' .. project .. " | grep nginx | grep master |grep -v grep")
	if #rs > 0 then
		runing = true
	end
	return runing
end

--当前路径
_M.pwd = trim(excute_cmd('pwd'))
--openresty的安装路径
_M.orpath = get_openresty_path()
--openresty的执行文件的路径
_M.openresty = _M.orpath .. '/bin/openresty'
--openresty的lualib路径
_M.orlualib = _M.orpath .. '/lualib'
--项目所在路径
_M.workpath = get_worker_path() or _M.pwd
--myor安装路径
_M.myorpath = get_myor_path()
--myor的lualib路径
_M.myorlualib = _M.myorpath .. '/lualib'
--项目名称
_M.project = get_folder_name(_M.workpath)
--系统名称
_M.os_name = trim(excute_cmd("uname"))
--系统可打开的最大文件数
_M.ulimit = tonumber(excute_cmd('ulimit -n'))
--cpu核心数量
_M.cpunum = tonumber(excute_cmd('grep processor /proc/cpuinfo|wc -l'))
--当前项目是否正在运行
_M.isrun = is_service_run(_M.project)

_M.excute = excute_cmd

--判定文件是否存在
_M.exist = function(path)
  local file = io.open(path, "rb")
  if file then file:close() end
  return file ~= nil
end

--如果文件存在则删除
_M.remove = function(file)
	local rm_exe = 'test -f ' .. file .. '&& rm ' .. file
	excute_cmd(rm_exe)
end

--创建一个软连接指向目标文件
_M.link = function(dest,link)
	_M.remove(link)
	local lnk_exe = 'ln -s ' .. dest .. ' ' .. link
	excute_cmd(lnk_exe)
end

--向文件中写入数据
_M.write = function(file_path, data)
    local file = io.open(file_path, "w+")
    if not file then
        return false, "failed to open file: " .. file_path
    end

    file:write(data)
    file:close()
    return true
end

--检查路径是否存在，如果不存在则创建
_M.check_path_and_mkdir = function(path)
	if path:sub(1,1) ~= '/' then return false end
	
	local pos = path:find('/')
	local dir = ''
	while pos do
		local npos = path:find('/', pos + 1)
		if not npos and pos < #path then npos = #path + 1 end
		if npos then
			dir = dir .. '/' .. path:sub(pos + 1, npos - 1)
			if not _M.exist(dir) then
				_M.excute('mkdir ' .. dir)
			end
		end
		pos = npos
	end
	
	return true
end

--复制文件到指定目录
_M.copy_file = function(file,path)
	_M.check_path_and_mkdir(path)
	
	local filename = get_folder_name(file)
	_M.excute('cp ' .. file .. ' ' .. path .. '/' .. filename)
end

return _M