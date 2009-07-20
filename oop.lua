local table = require "luv.table"
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
		tbl.parent = self
		setmetatable(tbl, {__index=self;__call=function (self, ...) return self:new(...) end})
		processProperties(tbl)
		return tbl
	end;
	new = function (self, ...)
		local obj = {new=self.maskedMethod;extend=self.maskedMethod;parent=self}
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
	isKindOf = function (self, obj)
		if obj and (self == obj or (self.parent and self.parent:isKindOf(obj))) then
			return true
		end
		return false
	end;
	abstractMethod = abstractMethod;
	maskedMethod = function () error("masked method "..debug.traceback()) end;
	singleton = function (self) return self end;
	property = function () end;
}

local TypedProperty = Object:extend{
	__tag = .....".TypedProperty";
	type = Object.property;
	init = function (self, type)
		self:type(type)
	end;
	createGetterAndSetter = function (self, name)
		local propType = self:type()
		if "string" == type(propType) then
			return function (self, ...)
				if 0 == select("#", ...) then
					return self["_"..name]
				else
					local val = (select(1, ...))
					if propType ~= type(val) then
						error(propType.." expected "..type(val).." given "..debug.traceback())
					end
					self["_"..name] = val
					return self
				end
			end
		else
			return function (self, ...)
				if 0 == select("#", ...) then
					return self["_"..name]
				else
					local val = (select(1, ...))
					if not val or not val.isKindOf or not val:isKindOf(propType) then
						error("given parameter type is not valid "..debug.traceback())
					end
					self["_"..name] = val
					return self
				end
			end
		end
	end;
}

Object.property = function (propType) return TypedProperty(propType) end

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
		elseif "table" == type(v) and v.isKindOf and v:isKindOf(TypedProperty) then
			self[k] = v:createGetterAndSetter(k)
		end
	end
end

return {Object=Object}
