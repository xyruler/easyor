--[[
class
可以创建可继承的类对象
--]]

--深拷贝
local function deep_copy(t, dest, aType)
	local t, r = t or {}, dest or {};
	for k,v in pairs(t) do
		if aType and type(v) == aType then 
			r[k] = v
		elseif not aType then
			if type(v) == 'table' and k ~= "__index" then
				r[k] = deep_copy(v)
			else
				r[k] = v
			end
		end
	end
	return r
end

--浅拷贝
local function shallow_copy(t, dest, aType)
	local t, r = t or {}, dest or {}
	for k,v in pairs(t) do
		r[k] = v
	end
	return r
end

--初始化类对象
local function instantiate(self,...)
	local instance = {}
	setmetatable(instance,self)
	instance.__metaclass = self
	instance.__bIns = true
	if self.__init then
		if type(self.__init) == 'table' then
			shallow_copy(self.__init, instance)
		else
			self.__init(instance, ...)
		end
	end
	return instance
end

--继承
local function extends(self,extra_params)
	local heir = {}
	deep_copy(extra_params, deep_copy(self, heir))
	heir.__index, heir.super = heir, self
	return setmetatable(heir,self)
end

--基础方法
baseMt = {
	__call = function (self,...)
		return self:new(...)
	end,
	__tostring = function(self,...)
		if self.__bIns then
			return ('object (of %s): <%s>'):format((rawget(getmetatable(self),'__name') or 'Unnamed'), tostring(self))
		else
			return ('class (%s): <%s>'):format((rawget(self,'__name') or 'Unnamed'),tostring[self])
		end
	end
};

local function toObject(self)
  local o = shallow_copy(self);
  o.__metaclass = nil;
  return o;
end

--class对象
local class = function(attr)
  local c = deep_copy(attr);
  c.with = function(self,include) return deep_copy(include, self, 'function')  end
  c.new, c.extends, c.__index, c.__call, c.__tostring, c.toObject = instantiate, extends, c, baseMt.__call, baseMt.__tostring, toObject;
  return setmetatable(c,baseMt);
end;

return class