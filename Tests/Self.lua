local UnitTest = require"UnitTest"

module(...)

local SelfTest = UnitTest:extend{
	testAsserts = function (self) assertTrue(true) assertFalse(false) assertEquals(1, 1) assertNotEquals(1, 2) assertNil(nil) assertNotNil({}) end,
	testThrows = function (self)
		assertThrows(assertTrue, false)
		assertThrows(assertFalse, true)
		assertThrows(assertEquals, 1, 2)
		assertThrows(assertNotEquals, 1, 1)
		assertThrows(assertNil, {})
		assertThrows(assertNotNil, nil)
	end,
	setUp = function (self)
		self.a = 10
	end,
	testSetUp = function (self)
		assertEquals(a, 10)
	end,
}

return SelfTest