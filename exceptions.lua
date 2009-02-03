local debug, type, error, pcall, _G = debug, type, error, pcall, _G
local Object = require"luv.oop".Object

module(...)

local ExceptionResult = Object:extend{
	__tag = .....".ExceptionResult",
	raised = false,
	init = function (self, res, exc)
		self.raised = not res
		self.exception = exc
	end,
	catch = function (self, excType, func)
		if not self.raised then
			return self
		end
		if type(excType) == "function" then
			excType(self.exception)
			self.raised = false
		end
		if type(self.exception) == "table" and self.exception:isKindOf(excType) then
			func(self.exception)
			self.raised = false
		end
		return self
	end,
	elseDo = function (self, func)
		if not self.raised then
			func(self.exception)
		end
		return self
	end,
	throw = function (self)
		if self.raised then
			if type(self.exception) == "table" then
				self.exception:throw()
			elseif type(self.exception) == "string" then
				error(self.exception)
			end
		end
	end
}

_G.try = function (...)
	return ExceptionResult(pcall(...))
end

local Exception = Object:extend{
	__tag = .....".Exception",
	init = function (self, message)
		self.message = message
		self.trace = debug.traceback("", 3)
	end,
	throw = function (self) error(self) end,
	__tostring = function (self) return self.message end
}

return {
	Exception = Exception
}
