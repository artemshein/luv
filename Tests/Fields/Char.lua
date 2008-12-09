local UnitTest, Char = require"UnitTest", require"Fields.Char"

module(...)

local CharTest = UnitTest:extend{
	testSimple = function (self)
		self.assertThrows(function() Char:new{} end)
		local f = Char:new{name = "test"}
		self.assertEquals(f.name, "test")
		self.assertFalse(f.required)
		self.assertFalse(f.unique)
		self.assertFalse(f.pk)
		f:setValue("value")
		self.assertTrue(f:getValue(), "value")
		self.assertEquals(f:getMaxLength(), 255)
	end
}

return CharTest