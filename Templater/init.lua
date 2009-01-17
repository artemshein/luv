local Object, Namespace = from"Luv":import("Object", "Namespace")

module(...)

local Api = Object:extend{
	__tag = .....".Api",
	
	init = function (self, templatesDir)
		self.templatesDir = templatesDir
	end,
	display = abstractMethod,
	fetch = abstractMethod,
	fetchString = abstractMethod,
	displayString = abstractMethod,
	assign = abstractMethod,
	clear = abstractMethod
}

return Namespace:extend{
	__tag = ...,

	ns = ...,
	Api = Api
}
