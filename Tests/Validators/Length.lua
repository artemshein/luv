local TestCase, Length = require"TestCase", require"Validators.Length"

module(...)

return TestCase:extend{
	__tag = "Tests.Validators.Length",

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
		v = Length:new(0, 5)
		self.assertTrue(v:validate(""))
		self.assertTrue(v:validate("12345"))
		self.assertTrue(v:validate(12345))
		self.assertFalse(v:validate("123456"))
		self.assertFalse(v:validate(1000000))
		self.assertTrue(v:validate())
		self.assertTrue(v:validate(true))
		self.assertTrue(v:validate(false))
		v = Length:new(5, 0)
		self.assertFalse(v:validate "abcd")
		self.assertTrue(v:validate "abcde")
		self.assertTrue(v:validate "abcdefgh")
	end
}
