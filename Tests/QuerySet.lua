local TestCase, QuerySet, Model, Int = require"TestCase", require"QuerySet", require"Models.Model", require"Fields.Int"
local Debug = require"Debug"

module(...)

return TestCase:extend{
	__tag = "Tests.QuerySet",

	testSimple = function (self)
		local q = QuerySet:new()
		self.assertTrue(q:isEmpty())
		self.assertEquals(#q, 0)
		self.assertThrows(function () q.append(10) end)
		local M = Model:extend{
			num = Int:new()
		}
		local q = QuerySet:new{M:new(), M:new(), M:new()}
		self.assertFalse(q:isEmpty())
		self.assertEquals(q:size(), 3)
		local q2 = q + QuerySet:new{M:new(), M:new()}
		self.assertNotEquals(q, q2)
		self.assertEquals(q2:size(), 5)
	end
}
