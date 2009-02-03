local TestCase = require"luv.unittest".TestCase

module(...)

return TestCase:extend{
	__tag = ...,
	testAsserts = function (self) self.assertTrue(true) self.assertFalse(false) self.assertEquals(1, 1) self.assertNotEquals(1, 2) self.assertNil(nil) self.assertNotNil({}) end,
	testThrows = function (self)
		self.assertThrows(self.assertTrue, false)
		self.assertThrows(self.assertFalse, true)
		self.assertThrows(assertEquals, 1, 2)
		self.assertThrows(assertNotEquals, 1, 1)
		self.assertThrows(assertNil, {})
		self.assertThrows(assertNotNil, nil)
	end,
	setUp = function (self)
		self.a = 10
	end,
	testSetUp = function (self)
		self.assertEquals(self.a, 10)
	end,
}
