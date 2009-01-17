local TestCase, QuerySet, Model, Fields, Debug = from"Luv":import("TestCase", "QuerySet", "Db.Model", "Fields", "Debug")

module(...)

return TestCase:extend{
	__tag = ...,

	testSimple = function (self)
		local q = QuerySet()
		self.assertTrue(q:isEmpty())
		self.assertEquals(#q, 0)
		self.assertThrows(function () q.append(10) end)
		local M = Model:extend{
			label = "test", labelMany = "tests",
			num = Fields.Int()
		}
		local q = QuerySet{M(), M(), M()}
		self.assertFalse(q:isEmpty())
		self.assertEquals(q:size(), 3)
		local q2 = q + QuerySet{M(), M()}
		self.assertNotEquals(q, q2)
		self.assertEquals(q2:size(), 5)
	end
}
