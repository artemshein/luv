local dofile, tostring, assert = dofile, tostring, assert
local string = require "luv.string"
local Object = require "luv.oop".Object

module(...)

local I18n = Object:extend{
	__tag = .....".I18n";
	init = function (self, dir, lang)
		self.dir = dir
		self.lang = lang
		self.messages = assert(dofile(tostring(dir / (lang..".lua"))))
	end;
	tr = function (self, message)
		return self.messages[message]
	end;
}

return {
	I18n=I18n;
}
