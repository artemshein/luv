local ipairs, io, require, type = ipairs, io, require, type
local rawget, getmetatable, rawset = rawget, getmetatable, rawset
local select = select
local table = require"luv.table"
local Object = require"luv.oop".Object
local Exception = require"luv.exceptions".Exception

module(...)

local MODULE = (...)
local property = Object.property

-- Main idea has been stolen from dklab.ru PHP classes.
-- Big thanks goes to Dmitry Koterov.

local Tag = Object:extend{
	__tag = .....".Tag";
	id = property"string";
	backend = property"table";
	init = function (self, backend, id)
		self:id(id)
		self:backend(backend)
	end;
	clear = function (self)
		self:backend():clearTags{self:id()}
	end;
}

local slotThruCall = function (self, ...)
	local res = self:slot():get()
	if not res then
		local obj, method = self:obj(), self:method()
		if obj then
			if method then
				local first = (select(1, ...))
				if "table" == type(first) and first.isA and first:isA(self:parent()) then
					res = obj[method](obj, select(2, ...))
				else
					res = obj[method](obj, ...)
				end
			elseif "function" == type(obj) then
				res = obj(...)
			else
				res = obj(obj, ...)
			end
		else
			if not method then
				Exception"nothing to call"
			end
			res = method(first, ...)
		end
		self:slot():set(res)
	end
	return res
end

local slotThruIndex = function (self, field)
	local res = rawget(self, "_parent")[field]
	if res then return res end
	if not rawget(self, "_method") then
		self:method(field)
	else
		Exception("сan't index twice "..field)
	end
	return self
end

local SlotThru = Object:extend{
	__tag = .....".SlotThru";
	__call = slotThruCall;
	__index = slotThruIndex;
	slot = property;
	obj = property;
	method = property;
	init = function (self, slot, obj)
		self:slot(slot)
		self:obj(obj)
	end;
}

local Slot = Object:extend{
	__tag = .....".Slot";
	id = property "string";
	defaultLifetime = property;
	backend = property"table";
	lifetime = property"number";
	tags = property"table";
	init = function (self, backend, id, lifetime)
		self:id(id)
		if lifetime then self:lifetime(lifetime) end
		self:backend(backend)
		self:tags{}
	end;
	get = function (self) return self:backend():get(self:id()) end;
	set = function (self, data)
		local tags = {}
		for _, tag in ipairs(self:tags()) do
			table.insert(tags, tag:id())
		end
		return self:backend():set(self:id(), data, tags, self:lifetime())
	end;
	delete = function (self) self._backend:delete(self:id()) end;
	addTag = function (self, tag)
		if tag:backend() ~= self:backend() then
			Exception"backends for tag and slot must be the same"
		end
		table.insert(self:tags(), tag)
	end;
	thru = function (self, obj) return SlotThru(self, obj) end;
}

return {Slot=Slot;Tag=Tag;}
