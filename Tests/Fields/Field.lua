local TestCase, Field = require"TestCase", require"Fields.Field"

module(...)

local FieldTest = TestCase:extend{
	testAbstract = function (self)
		self.assertThrows(function () Field:new{name = "testName"} end)
	end
}

return FieldTest