require "luv.string"
local type, string, table, pairs = type, string, table, pairs
local Object = require"luv.oop".Object

module(...)

local Api = Object:extend{
	__tag = .....".Api",
	init = function (self, templatesDirOrDirs)
		if "string" == type(templatesDirOrDirs) then
			self.templatesDirs = {templatesDirOrDirs}
		else
			self.templatesDirs = {}
			if "table" == type(templatesDirOrDirs) then
				local _, v for _, v in pairs(templatesDirOrDirs) do
					self:addTemplatesDir(v)
				end
			end
		end
	end,
	addTemplatesDir = function (self, dir)
		if not string.endsWith(dir, "/") and not string.endsWith(dir, "\\") then
			dir = dir.."/"
		end
		table.insert(self.templatesDirs, dir)
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
