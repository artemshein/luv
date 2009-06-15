local ipairs, io = ipairs, io
local rawget, getmetatable = rawget, getmetatable
local table = require "luv.table"
local Object = require "luv.oop".Object
local Exception = require "luv.exceptions".Exception

module(...)

-- Main idea has been stolen from dklab.ru PHP classes.
-- Big thanks goes to Dmitry Koterov.

local Tag = Object:extend{
	__tag = .....".Tag";
	init = function (self, backend, id)
		self.id = id
		self.backend = backend
	end;
	clear = function (self)
		self.backend:clearTags{self:getNativeId()}
	end;
	getNativeId = function (self) return self.id end;
	getBackend = function (self) return self.backend end;
}

local slotThruCall = function (self, ...)
	local res = self.slot:get()
	if not rawget(self, "method") then
		Exception "Index first!"
	end
	if not res then
		if self.obj then
			res = self.obj[self.method](self.obj, ...)
		else
			res = self.method(...)
		end
		self.slot:set(res)
	end
	return res
end

local slotThruIndex = function (self, field)
	local parent = rawget(self, "parent")
	local res = parent[field]
	if res then return res end
	if not rawget(self, "method") then
		self.method = field
	else
		Exception("Can't index twice! "..field)
	end
	return self
end

local SlotThru = Object:extend{
	__tag = .....".SlotThru";
	init = function (self, slot, obj)
		if not slot or not obj then
			Exception "Slot and obj expected!"
		end
		self.slot = slot
		self.obj = obj
		getmetatable(self).__call = slotThruCall
		getmetatable(self).__index = slotThruIndex
	end;
}

local Slot = Object:extend{
	__tag = .....".Slot";
	init = function (self, backend, id, lifetime)
		self.id = id
		self.lifetime = lifetime
		self.backend = backend
		self.tags = {}
	end;
	get = function (self) return self.backend:get(self.id) end;
	set = function (self, data)
		local tags = {}
		for _, tag in ipairs(self.tags) do
			table.insert(tags, tag:getNativeId())
		end
		return self.backend:set(self.id, data, tags, self.lifetime)
	end;
	delete = function (self) self.backend:delete(self.id) end;
	addTag = function (self, tag)
		if tag:getBackend() ~= self.backend then
			Exception"Backends for tag and slot must be the same"
		end
		table.insert(self.tags, tag)
	end;
	getLifetime = function (self) return self.lifetime end;
	setLifetime = function (self, lifetime) self.lifetime = lifetime return self end;
	thru = function (self, obj) return SlotThru(self, obj) end;
}

return {Slot=Slot;Tag=Tag}
