local ipairs = ipairs
local Object = require "luv.oop".Object

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

--[[ TODO
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
		res = rawget(self, "slot"):get()
		if not res then
			local obj = rawget(self, "obj")
			if obj then
				res = obj[field]
			end
		end
	end;
}]]

local Slot = Object:extend{
	__tag = .....".Slot";
	init = function (self, backend, id, lifetime)
		self.id = id
		self.lifetime = lifetime
		self.backend = backend
		self.tags = {}
	end;
	get = function (self)
		return self.backend:get(self.id)
	end;
	set = function (self, data)
		local tags
		for _, tag in ipairs(self.tags) do
			table.insert(tags, tag:getNativeId())
		end
		return self.backend:set(self.id, data, tags, self.lifetime)
	end;
	delete = function (self) self.backend:delete(self.id) end;
	addTag = function (self, tag)
		if tag:getBackend() ~= self.backend then
			Exception"Backends for tag and slot must be the same":throw()
		end
		table.insert(self.tags, tag)
	end;
	--[[ TODO
	thru = function (self, obj)
		return SlotThru(self, obj)
	end;]]
}

return {Slot=Slot;Tag=Tag}
