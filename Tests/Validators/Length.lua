local UnitTest, Length = require"UnitTest", require"Validators.Length"

module(...)

local LengthTest = UnitTest:extend{
	testSimple = function (self)
		v = Length:new(5, 10)
		self.assertTrue(v:validate("12345"))
		self.assertTrue(v:validate("1234567891"))
		self.assertFalse(v:validate("1234"))
		self.assertFalse(v:validate("12345678910"))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate(10))
		self.assertFalse(v:validate())
		self.assertTrue(v:validate(10000))
		self.assertFalse(v:validate(false))
		self.assertFalse(v:validate(true))
		v = Length:new(5)
		self.assertTrue(v:validate(""))
		self.assertTrue(v:validate("12345"))
		self.assertTrue(v:validate(12345))
		self.assertFalse(v:validate("123456"))
		self.assertFalse(v:validate(1000000))
		self.assertTrue(v:validate())
		self.assertTrue(v:validate(true))
		self.assertTrue(v:validate(false))
	end
}

return LengthTest