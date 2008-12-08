local UnitTest, Field = require"UnitTest", require"Fields.Field"

module(...)

local FieldTest = UnitTest:extend{
	testInitialization = function (self)
		self.assertThrows(Field:new{name = "testName"})
	end
}

return FieldTest

--[[
local f = Field:new{name = "testName"}
		assertEquals(f.name, "testName")
		assertFalse(f.required)
		assertFalse(f.unique)
		assertNil(f.defaultValue)
		assertFalse(f.pk)]]--