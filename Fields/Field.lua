local Object = require"ProtOo"

module(...)

local Field = Object:extend{
	pk = false,
	unique = false,
	required = false,
	
	init = abstractMethod,
	setParams = function (self, params)
		if params.pk then
			self.pk = params.pk
		end
		if params.unique then
			self.unique = params.unique
		end
		if params.required then
			self.required = params.required
		end
	end
}

return Field