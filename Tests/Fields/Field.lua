local UnitTest, Field = require"UnitTest", require"Fields.Field"

module(...)

local FieldTest = UnitTest:extend{
	testAbstract = function (self)
		self.assertThrows(function () Field:new{name = "testName"} end)
	end
}

return FieldTest