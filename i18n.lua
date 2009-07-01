local dofile, tostring, assert = dofile, tostring, assert
local string = require "luv.string"
local Object = require "luv.oop".Object
local fs = require "luv.fs"

module(...)

local I18n = Object:extend{
	__tag = .....".I18n";
	init = function (self, dir, lang)
		self._dir = dir
		if "table" ~= self._dir then
			self._dir = fs.Dir(self._dir)
		end
		self._lang = lang
		self._msgs = assert(dofile(tostring(self._dir / (self._lang..".lua"))))
	end;
	tr = function (self, message)
		return self._msgs[message]
	end;
}

return {
	I18n=I18n;
}
