local Object, Exception = require"ProtOo", require"Exception"
local type = type

module(...)

local Field = Object:extend{
	pk = false,
	unique = false,
	required = false,
	
	init = abstractMethod,
	setParams = function (self, params)
		if (not params.name) or type(params.name) ~= "string" then
			Exception:new"name required!":throw()
		end
		self.name = params.name
		if params.pk then
			self.pk = params.pk
		end
		if params.unique then
			self.unique = params.unique
		end
		if params.required then
			self.required = params.required
		end
		return self
	end,
	getValue = function (self)
		return self.value
	end,
	setValue = function (self, value)
		self.value = value
		return self
	end
}

return Field