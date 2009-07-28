local ipairs, io, require = ipairs, io, require
local rawget, getmetatable = rawget, getmetatable
local table = require "luv.table"
local Object = require "luv.oop".Object
local Exception = require "luv.exceptions".Exception

module(...)
local property = Object.property

-- Main idea has been stolen from dklab.ru PHP classes.
-- Big thanks goes to Dmitry Koterov.

local Tag = Object:extend{
	__tag = .....".Tag";
	id = property "string";
	init = function (self, backend, id)
		self:id(id)
		self:backend(backend)
	end;
	clear = function (self)
		self:backend():clearTags{self:id()}
	end;
}

local slotThruCall = function (self, ...)
	local res = self._slot:get()
	if not res then
		if self._obj then
			if rawget(self, "_method") then
				res = self._obj[self._method](self._obj, ...)
			else
				res = self._obj(self._obj, ...)
			end
		else
			if not self._method then
				Exception "nothing to call"
			end
			res = self._method(...)
		end
		self._slot:set(res)
	end
	return res
end

local slotThruIndex = function (self, field)
	local parent = rawget(self, "parent")
	local res = parent[field]
	if res then return res end
	if not rawget(self, "method") then
		self._method = field
	else
		Exception("Can't index twice! "..field)
	end
	return self
end

local SlotThru = Object:extend{
	__tag = .....".SlotThru";
	__call = slotThruCall;
	__index = slotThruIndex;
	init = function (self, slot, obj)
		if not slot or not obj then
			Exception "Slot and obj expected!"
		end
		self._slot = slot
		self._obj = obj
	end;
}

local Slot = Object:extend{
	__tag = .....".Slot";
	id = property "string";
	defaultLifetime = property;
	init = function (self, backend, id, lifetime)
		self:id(id)
		self._lifetime = lifetime
		self._backend = backend
		self._tags = {}
	end;
	get = function (self) return self._backend:get(self._id) end;
	set = function (self, data)
		local tags = {}
		for _, tag in ipairs(self._tags) do
			table.insert(tags, tag:id())
		end
		return self._backend:set(self._id, data, tags, self._lifetime)
	end;
	delete = function (self) self._backend:delete(self._id) end;
	addTag = function (self, tag)
		if tag:backend() ~= self._backend then
			Exception"Backends for tag and slot must be the same"
		end
		table.insert(self._tags, tag)
	end;
	thru = function (self, obj) return SlotThru(self, obj) end;
}

return {
	Slot=Slot;Tag=Tag;
}
