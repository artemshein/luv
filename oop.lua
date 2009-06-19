local table = require "luv.table"
local tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset = tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset
local ipairs = ipairs
local require = require

module(...)

local abstractMethod = function (self) require "luv.dev".dprint(self, 3) error "method must be implemented first" end

local Object = {
	__tag = .....".Object";
	init = abstractMethod;
	extend = function (self, tbl)
		tbl.parent = self
		setmetatable(tbl, {__index=self;__call=function (self, ...) return self:new(...) end})
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
	maskedMethod = function () error("Masked method! "..debug.traceback()) end;
	singleton = function (self) return self end;
}

return {Object=Object}
