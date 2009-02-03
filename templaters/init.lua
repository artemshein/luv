local Object = require"luv.oop".Object

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

return {
	Api = Api
}
