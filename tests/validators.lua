local Validators, TestCase = require"luv.validators", require"luv.unittest".TestCase

module(...)

local Filled = TestCase:extend{
	__tag = .....".Filled",
	testSimple = function (self)
		local v = Validators.Filled()
		self.assertTrue(v:validate("1"))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertTrue(v:validate(0))
		self.assertTrue(v:validate(1))
		self.assertTrue(v:validate({}))
	end
}

local Int = TestCase:extend{
	__tag = .....".Int",
	testSimple = function (self)
		local v = Validators.Int()
		self.assertTrue(v:validate(10))
		self.assertTrue(v:validate(0))
		self.assertTrue(v:validate("10"))
		self.assertTrue(v:validate("-1"))
		self.assertFalse(v:validate(""))
		self.assertTrue(v:validate())
		self.assertFalse(v:validate(true))
		self.assertFalse(v:validate(false))
		self.assertTrue(v:validate("0.43e-23"))
	end
}

local Length = TestCase:extend{
	__tag = .....".Length",
	testSimple = function (self)
		v = Validators.Length(5, 10)
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
		v = Validators.Length(0, 5)
		self.assertTrue(v:validate(""))
		self.assertTrue(v:validate("12345"))
		self.assertTrue(v:validate(12345))
		self.assertFalse(v:validate("123456"))
		self.assertFalse(v:validate(1000000))
		self.assertTrue(v:validate())
		self.assertTrue(v:validate(true))
		self.assertTrue(v:validate(false))
		v = Validators.Length(5, 0)
		self.assertFalse(v:validate "abcd")
		self.assertTrue(v:validate "abcde")
		self.assertTrue(v:validate "abcdefgh")
	end
}

local Regexp = TestCase:extend{
	__tag = .....".Regexp",
	testSimple = function (self)
		local r = Validators.Regexp"^%d%d%-%d%d%-%d%d%d%d$"
		self.assertFalse(r:validate"")
		self.assertTrue(r:validate"10-12-2005")
		self.assertFalse(r:validate"101-10-2008")
	end
}

local Value = TestCase:extend{
	__tag = .....".Value",
	testSimple = function (self)
		local v = Validators.Value"test"
		self.assertTrue(v:validate("test"))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertFalse(v:validate(false))
		self.assertFalse(v:validate(true))
		self.assertFalse(v:validate(25))
		v = Validators.Value"25"
		self.assertTrue(v:validate("25"))
		self.assertTrue(v:validate(25))
		self.assertFalse(v:validate(26))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertFalse(v:validate(false))
		self.assertFalse(v:validate(true))
		v = Validators.Value(-0.25)
		self.assertTrue(v:validate("-0.25"))
		self.assertTrue(v:validate(-0.25))
		self.assertFalse(v:validate(-0.26))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertFalse(v:validate(false))
		self.assertFalse(v:validate(true))
	end
}

return {
	Filled = Filled,
	Int = Int,
	Length = Length,
	Regexp = Regexp,
	Value = Value
}
