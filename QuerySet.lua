local pairs, require, type, tostring, io, unpack = pairs, require, type, tostring, io, unpack
local Table, Object, Model, Exception = require"Table", require"ProtOo", require"Models.Model", require"Exception"

module(...)

local args = {...}

return Object:extend{
	__tag = "QuerySet",

	init = function (self, values)
		self.values = {}
		if not values then
			return
		end
		if type(values) ~= "table" then
			Exception:new"Table required!":throw()
		end
		local _, v
		for _, v in pairs(values) do
			self:append(v)
		end
	end,
	size = function (self)
		return #self.values
	end,
	__len = function (self)
		return self:size()
	end,
	isEmpty = function (self)
		return #self.values == 0
	end,
	append = function (self, value)
		if not value:isKindOf(Model) then
			Exception:new"Instance of Model required!":throw()
		end
		Table.insert(self.values, value)
	end,
	pairs = function (self)
		return pairs(self.values)
	end,
	__add = function (self, value)
		local res = require(unpack(args)):new(self.values)
		if value:isKindOf(Model) then
			res:append(value)
		elseif value:isKindOf(require(unpack(args))) then
			local _, v
			for _, v in value:pairs() do
				res:append(v)
			end
		else
			Exception:new"Instance of QuerySet or Model required!":throw()
		end
		return res
	end
}
