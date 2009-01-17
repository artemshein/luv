local pairs, require, type, tostring, io, unpack = pairs, require, type, tostring, io, unpack
local Table, Object, Model, Exception = from"Luv":import("Table", "Object", "Db.Model", "Exception")

module(...)

local CLASS = ...

return Object:extend{
	__tag = ...,

	init = function (self, values)
		self.values = {}
		if not values then
			return
		end
		if type(values) ~= "table" then
			Exception"Table required!":throw()
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
			Exception"Instance of Model required!":throw()
		end
		Table.insert(self.values, value)
	end,
	pairs = function (self)
		return pairs(self.values)
	end,
	__add = function (self, value)
		local res = require(CLASS)(self.values)
		if value:isKindOf(Model) then
			res:append(value)
		elseif value:isKindOf(require(CLASS)) then
			local _, v
			for _, v in value:pairs() do
				res:append(v)
			end
		else
			Exception"Instance of QuerySet or Model required!":throw()
		end
		return res
	end
}
