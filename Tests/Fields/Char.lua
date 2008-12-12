local UnitTest, Char = require"UnitTest", require"Fields.Char"

module(...)

local CharTest = UnitTest:extend{
	testSimple = function (self)
		local f = Char:new()
		self.assertFalse(f:isRequired())
		self.assertFalse(f:isUnique())
		self.assertFalse(f:isPk())
		f:setValue("value")
		self.assertTrue(f:getValue(), "value")
		self.assertEquals(f:getMaxLength(), 255)
	end,
	testMaxLength = function (self)
		local f = Char:new{maxLength = 10}
		f:setValue("1234567890")
		self.assertEquals(f:getValue(), "1234567890")
		self.assertTrue(f:validate())
		f:setValue("12345678901")
		self.assertFalse(f:validate())
	end,
	testMinLength = function (self)
		local f = Char:new{minLength = 4, maxLength = 6}
		f:setValue("123")
		self.assertFalse(f:validate())
		f:setValue("1234")
		self.assertTrue(f:validate())
		f:setValue("123456")
		self.assertTrue(f:validate())
		f:setValue("1234567")
		self.assertFalse(f:validate())
	end
}

return CharTest