local f = require "luv.function".f
local TestCase = require "luv.dev.unittest".TestCase

module(...)

return TestCase:extend{
	__tag = ...;
	testF = function (self)
		self.assertThrows(function () f "a *+ b" end)
		self.assertEquals(f "a*a"(2), 4)
		self.assertEquals(f "a+b+c+d+e+f"(1, 10, 100, 1000, 10000, 100000), 111111)
	end;
}
