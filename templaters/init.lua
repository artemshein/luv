local type = type
local Object = require"luv.oop".Object

module(...)

local Api = Object:extend{
	__tag = .....".Api",
	init = function (self, templatesDirOrDirs)
		if "string" == type(templatesDirOrDirs) then
			self.templatesDirs = {templatesDirOrDirs}
		else
			self.templatesDirs = templatesDirOrDirs
		end
	end,
	addTemplatesDir = abstractMethod,
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
