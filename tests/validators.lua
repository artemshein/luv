local Validators, TestCase = require "luv.validators", require "luv.dev.unittest".TestCase

module(...)

local Filled = TestCase:extend{
	__tag = .....".Filled",
	testSimple = function (self)
		local v = Validators.Filled()
		self.assertTrue(v:isValid("1"))
		self.assertFalse(v:isValid(""))
		self.assertFalse(v:isValid())
		self.assertTrue(v:isValid(0))
		self.assertTrue(v:isValid(1))
		self.assertFalse(v:isValid({}))
	end
}

local Int = TestCase:extend{
	__tag = .....".Int",
	testSimple = function (self)
		local v = Validators.Int()
		self.assertTrue(v:isValid(10))
		self.assertTrue(v:isValid(0))
		self.assertTrue(v:isValid("10"))
		self.assertTrue(v:isValid("-1"))
		self.assertFalse(v:isValid(""))
		self.assertTrue(v:isValid())
		self.assertFalse(v:isValid(true))
		self.assertFalse(v:isValid(false))
		self.assertTrue(v:isValid("0.43e-23"))
	end
}

local Length = TestCase:extend{
	__tag = .....".Length",
	testSimple = function (self)
		v = Validators.Length(5, 10)
		self.assertTrue(v:isValid("12345"))
		self.assertTrue(v:isValid("1234567891"))
		self.assertFalse(v:isValid("1234"))
		self.assertFalse(v:isValid("12345678910"))
		self.assertTrue(v:isValid(""))
		self.assertFalse(v:isValid(10))
		self.assertTrue(v:isValid())
		self.assertTrue(v:isValid(10000))
		self.assertFalse(v:isValid(false))
		self.assertFalse(v:isValid(true))
		v = Validators.Length(0, 5)
		self.assertTrue(v:isValid(""))
		self.assertTrue(v:isValid("12345"))
		self.assertTrue(v:isValid(12345))
		self.assertFalse(v:isValid("123456"))
		self.assertFalse(v:isValid(1000000))
		self.assertTrue(v:isValid())
		self.assertTrue(v:isValid(true))
		self.assertTrue(v:isValid(false))
		v = Validators.Length(5, 0)
		self.assertFalse(v:isValid "abcd")
		self.assertTrue(v:isValid "abcde")
		self.assertTrue(v:isValid "abcdefgh")
	end
}

local Regexp = TestCase:extend{
	__tag = .....".Regexp",
	testSimple = function (self)
		local r = Validators.Regexp"^%d%d%-%d%d%-%d%d%d%d$"
		self.assertTrue(r:isValid"")
		self.assertTrue(r:isValid"10-12-2005")
		self.assertFalse(r:isValid"101-10-2008")
	end
}

local Value = TestCase:extend{
	__tag = .....".Value",
	testSimple = function (self)
		local v = Validators.Value"test"
		self.assertTrue(v:isValid("test"))
		self.assertFalse(v:isValid(""))
		self.assertFalse(v:isValid())
		self.assertFalse(v:isValid(false))
		self.assertFalse(v:isValid(true))
		self.assertFalse(v:isValid(25))
		v = Validators.Value"25"
		self.assertTrue(v:isValid("25"))
		self.assertTrue(v:isValid(25))
		self.assertFalse(v:isValid(26))
		self.assertFalse(v:isValid(""))
		self.assertFalse(v:isValid())
		self.assertFalse(v:isValid(false))
		self.assertFalse(v:isValid(true))
		v = Validators.Value(-0.25)
		self.assertTrue(v:isValid("-0.25"))
		self.assertTrue(v:isValid(-0.25))
		self.assertFalse(v:isValid(-0.26))
		self.assertFalse(v:isValid(""))
		self.assertFalse(v:isValid())
		self.assertFalse(v:isValid(false))
		self.assertFalse(v:isValid(true))
	end
}

return {
	Filled = Filled,
	Int = Int,
	Length = Length,
	Regexp = Regexp,
	Value = Value
}
