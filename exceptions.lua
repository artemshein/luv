local debug, type, error, pcall, require = debug, type, error, pcall, require
local Object = require"luv.oop".Object

module(...)

local Exception = Object:extend{
	__tag = .....".Exception",
	init = function (self, msg, nothrow, depth)
		self._msg = msg
		self._trace = debug.traceback("", depth and depth+3 or 3)
		if not nothrow then self:throw() end
	end;
	getMsg = function (self) return self._msg end;
	getTrace = function (self) return self._trace end;
	throw = function (self) error(self) end;
	__tostring = function (self) return self._msg.." "..self._trace end;
}

local ExceptionResult = Object:extend{
	__tag = .....".ExceptionResult";
	init = function (self, res, exc)
		self._raised = not res
		self._exception = exc
	end;
	catch = function (self, excType, func)
		if not self._raised then
			return self
		end
		if type(excType) == "function" then
			excType(self._exception)
			self._raised = false
		end
		if type(self._exception) == "table" and self._exception:isKindOf(excType) then
			func(self._exception)
			self._raised = false
		end
		return self
	end;
	elseDo = function (self, func)
		if not self._raised then
			func(self._exception)
		end
		return self
	end;
	throw = function (self)
		if self._raised then
			if type(self._exception) == "table" then
				self._exception:throw()
			elseif type(self._exception) == "string" then
				error(self._exception)
			end
		end
	end;
	finally = function (self, func)
		func(self._exception)
		return self
	end;
}

local function try (...)
	return ExceptionResult(pcall(...))
end

return {Exception=Exception;try=try}
