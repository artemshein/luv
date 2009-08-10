local table = require "luv.table"
local loadstring, assert = loadstring, assert
local tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset = tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset
local ipairs, debug, require, select = ipairs, debug, require, select

module(...)

local abstractMethod = function () error("method must be implemented first "..debug.traceback()) end

local function processProperties (self)
	local property = self.property
	for k, v in pairs(self) do
		if v == property then
			self[k] = function (self, ...)
				if 0 == select("#", ...) then
					return self["_"..k]
				else
					self["_"..k] = (select(1, ...))
					return self
				end
			end
		end
	end
end

local Object = {
	__tag = .....".Object";
	init = abstractMethod;
	extend = function (self, tbl)
		tbl._parent = self
		setmetatable(tbl, {__index=self;__call=function (self, ...) return self:new(...) end})
		processProperties(tbl)
		return tbl
	end;
	new = function (self, ...)
		local obj = {new=self.maskedMethod;extend=self.maskedMethod;_parent=self}
		local magicMethods = {"__add";"__sub";"__mul";"__div";"__mod";"__pow";"__unm";"__concat";"__len";"__eq";"__lt";"__le";"__index";"__newindex";"__call";"__tostring"}
		local mt = table.copy(getmetatable(self) or {})
		mt.__index = nil
		for _, v in ipairs(magicMethods) do
			local method = self[v]
			if method then
				rawset(mt, v, method)
			end
		end
		if not mt.__index then
			mt.__index = self
		end
		setmetatable(obj, mt)
		self.init(obj, ...)
		return obj
	end;
	clone = function (self)
		local new = table.copy(self)
		setmetatable(new, getmetatable(self))
		return new
	end;
	isA = function (self, class)
		local parent = self._parent
		return self == class or (parent and parent:isA(class))
	end;
	parent = function (self) return self._parent end;
	abstractMethod = abstractMethod;
	maskedMethod = function () error("masked method "..debug.traceback()) end;
	singleton = function (self) return self end;
	property = function () end;
}

local Property = Object:extend{
	__tag = .....".Property";
	type = Object.property;
	getter = Object.property;
	setter = Object.property;
	init = function (self, propType, getter, setter)
		self:type(propType)
		self:getter(getter)
		self:setter(setter)
	end;
	createGetterAndSetter = function (self, name)
		local propType, getter, setter = self:type(), self:getter(), self:setter()
		local typeTest
		if propType then
			if "string" == type(propType) then
				typeTest = function (value)
					local valueType = type(value)
					if propType ~= valueType then
						error(propType.." expected "..valueType.." given "..debug.traceback())
					end
				end
			else
				typeTest = function (value)
					if not value or not value.isA or not value:isA(propType) then
						error("invalid type of parameter "..debug.traceback())
					end
				end
			end
		else
			typeTest = function () end
		end
		if not getter then
			getter = function (self) return self["_"..name] end
		elseif "string" == type(getter) then
			getter = assert(loadstring("return function (self) return "..getter.." end"))()
		end
		if not setter then
			setter = function (self, value) self["_"..name] = value return self end
		elseif "string" == type(setter) then
			setter = assert(loadstring("return function (self, value) "..setter.." = value return self end"))()
		end
		return function (self, ...)
			if 0 == select("#", ...) then
				return getter(self)
			else
				local value = (select(1, ...))
				typeTest(value)
				return setter(self, value)
			end
		end
	end;
}

Object.property = function (propType, getter, setter) return Property(propType, getter, setter) end

processProperties = function  (self)
	local property = self.property
	for k, v in pairs(self) do
		if v == property then
			self[k] = function (self, ...)
				if 0 == select("#", ...) then
					return self["_"..k]
				else
					self["_"..k] = (select(1, ...))
					return self
				end
			end
		elseif "table" == type(v) and v.isA and v:isA(Property) then
			self[k] = v:createGetterAndSetter(k)
		end
	end
end

return {Object=Object}
