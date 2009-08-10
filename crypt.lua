local string = string
local Object = require"luv.oop".Object
local Filter = require"datafilter"

module(...)

local property = Object.property

local Hash = Object:extend{
	__tag = .....".Hash";
	hash = property;
}

local Md5 = Hash:extend{
	__tag = .....".Md5",
	init = function (self, msg)
		self:hash(Filter.md5(msg))
	end;
	__tostring = function (self)
		return Filter.hex_lower(self:hash())
	end;
}

local Sha1 = Hash:extend{
	__tag = .....".Sha1",
	init = function (self, msg)
		self:hash(Filter.sha1(msg))
	end;
	__tostring = function (self)
		return Filter.hex_lower(self:hash())
	end
}

local hashers = {md5=Md5;sha1=Sha1}

return {
	Md5 = Md5;
	Sha1 = Sha1;
	hash = function (method, data)
		local hasher = hashers[string.lower(method)]
		return hasher and hasher(data) or Exception"unsupported hash algorithm"
	end;
}
