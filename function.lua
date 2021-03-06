local require, setfenv, getfenv = require, setfenv, getfenv
local Object = require"luv.oop".Object

module(...)

local property = Object.property

local Decorator = Object:extend{
	__tag = .....".Decorator";
	__call = function (self, func)
		return function (...)
			local f = self:func()
			setfenv(f, getfenv(1))
			return f(func, ...)
		end
	end;
	__add = function (self, func, ...)
		return self(func, ...)
	end;
	__sub = function (self, func, ...)
		return self(func, ...)
	end;
	__mul = function (self, func, ...)
		return self(func, ...)
	end;
	__mod = function (self, func, ...)
		return self(func, ...)
	end;
	__pow = function (self, func, ...)
		return self(func, ...)
	end;
	__concat = function (self, func, ...)
		return self(func, ...)
	end;
	func = property;
	init = function (self, func)
		self:func(func)
	end;
}

return {checkTypes = checkTypes; Decorator = Decorator}
