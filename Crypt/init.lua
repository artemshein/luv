local Object, Namespace = from"Luv":import("Object", "Namespace")
local Filter = require"datafilter"

module(...)

local Hash = Object:extend{__tag = .....",Hash"}

local Md5 = Hash:extend{
	__tag = .....".Md5",

	init = function (self, msg)
		self.hash = Filter.md5(msg)
	end,
	getHash = function (self)
		return self.hash
	end,
	__tostring = function (self)
		return Filter.hex_lower(self.hash)
	end
}

local Sha1 = Hash:extend{
	__tag = .....".Sha1",

	init = function (self, msg)
		self.hash = Filter.sha1(msg)
	end,
	getHash = function (self)
		return self.hash
	end,
	__tostring = function (self)
		return Filter.hex_lower(self.hash)
	end
}

return Namespace:extend{
	__tag = ...,

	ns = ...,
	Md5 = Md5,
	Sha1 = Sha1
}
