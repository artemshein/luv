local Object = require"ProtOo"

module(...)

local Templater = Object:extend{
	__tag = "Templaters.Templater",
	
	init = function (self, templatesDir)
		self.templatesDir = templatesDir
	end,
	display = abstractMethod,
	fetch = abstractMethod,
	fetchString = abstractMethod,
	displayString = abstractMethod,
	assign = abstractMethod,
	clear = abstractMethod,
}

return Templater