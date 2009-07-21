local debug, type, error, pcall, require = debug, type, error, pcall, require
local Object = require"luv.oop".Object

module(...)

local Exception = Object:extend{
	__tag = .....".Exception";
	msg = Object.property;
	trace = Object.property;
	init = function (self, msg, nothrow, depth)
		self:msg(msg)
		self:trace(debug.traceback("", depth and depth+3 or 3))
		if not nothrow then self:throw() end
	end;
	throw = function (self) error(self) end;
	__tostring = function (self) return self:msg().." "..self:trace() end;
}

local ExceptionResult = Object:extend{
	__tag = .....".ExceptionResult";
	raised = Object.property;
	exception = Object.property;
	init = function (self, res, exc)
		self:raised(not res)
		self:exception(exc)
	end;
	catch = function (self, excType, func)
		if not self:raised() then
			return self
		end
		if type(excType) == "function" then
			excType(self:exception())
			self:raised(false)
		end
		if type(self:exception()) == "table" and self:exception():isA(excType) then
			func(self:exception())
			self:raised(false)
		end
		return self
	end;
	elseDo = function (self, func)
		if not self:raised() then
			func(self:exception())
		end
		return self
	end;
	throw = function (self)
		if self:raised() then
			if type(self:exception()) == "table" then
				self:exception():throw()
			elseif type(self:exception()) == "string" then
				error(self:exception())
			end
		end
	end;
	finally = function (self, func)
		func(self:exception())
		return self
	end;
}

local function try (...)
	return ExceptionResult(pcall(...))
end

return {Exception=Exception;try=try}
