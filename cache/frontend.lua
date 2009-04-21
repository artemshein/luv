local Exception = require "luv.exceptions".Exception

module(...)

-- Main idea has been stolen from dklab.ru PHP classes.
-- Big thanks goes to Dmitry Koterov.

local Tag = Object:extend{
	__tag = .....".Tag";
	init = function (self, backend, id)
		self.id = id
		seld.backend = backend
	end;
	clean = function (self)
		self.backend:cleanTags{self:getNativeId()}
	end;
	getNativeId = function (self) return self.id end;
	getBackend = function (self) return self.backend end;
}

local SlotThru = Object:extend{
	__tag = .....".SlotThru";
	init = function (self, slot, obj)
		self.slot = slot
		self.obj = obj
	end;
	__index = function (self, field)
		local parent = rawget(self, "parent")
		local res = parent[field]
		if res then return res end
		if not rawget(self, "method") then
			self.method = field
		else
			Exception "Can't index twice!":throw()
		end
		return self
	end;
	__call = function (self, ...)
		local res = self.slot:get()
		if not rawget(self, "method") then
			Exception "Index first!":throw()
		end
		if not res then
			if self.obj then
				res = self.obj[self.method](self.obj, ...)
			else
				res = self.method(...)
			end
			self.slot:save(res)
		end
		return res
	end;
}

local Slot = Object:extend{
	__tag = .....".Slot";
	init = function (self, id, backend, lifetime)
		self.id = id
		self.lifetime = lifetime
		self.backend = backend
		self.tags = {}
	end;
	get = function (self) return self.backend:get(self.id) end;
	set = function (self, data)
		local tags, _, tag = {}
		for _, tag in ipairs(self.tags) do
			table.insert(tags, tag:getNativeId())
		end
		local raw = serialize(data)
		return self.backend:set(id, raw, tags, self.lifetime)
	end;
	delete = function (self) self.backend:delete(self.id) end;
	addTag = function (self, tag)
		if tag:getBackend() ~= self.backend then
			Exception"Backends for tag and slot must be the same":throw()
		end
		table.insert(self.tags, tag)
	end;
	thru = function (self, obj) return SlotThru(self, obj) end;
}
