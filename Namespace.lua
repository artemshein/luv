local require, rawset, rawget, io, getmetatable = require, rawset, rawget, io, getmetatable
local Object, Exception, Table = require"Luv.Object", require"Luv.Exception", require"Luv.Table"

module(...)

local searchMod = function (self, mod)
	local res = self.parent[mod]
	if res then return res end
	local ns = rawget(self, "ns")
	if not ns then
		Exception"ns must be defined!":throw()
	end
	local res = require(self.ns.."."..mod)
	if not res then
		Exception(mod.." not founded in "..self.ns.."!"):throw()
	end
	rawset(self, mod, res)
	return res
end

return Object:extend{
	__tag = ...,

	extend = function (self, new)
		local new = Object.extend(self, new)
		getmetatable(new).__index = searchMod
		return new
	end
}
