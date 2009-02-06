require "luv.debug"
local string, debug = string, debug
local Object = require"luv.oop".Object
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

return {
	Md5 = Md5,
	Sha1 = Sha1,
	hash = function (method, data)
		method = string.lower(method)
		if method == "md5" then
			return Md5(data)
		elseif method == "sha1" then
			return Sha1(data)
		end
		Exception "Unsupported hashing algorithm!":throw()
	end
}
