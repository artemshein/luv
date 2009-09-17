local Validators, TestCase = require "luv.validators", require "luv.dev.unittest".TestCase

module(...)

local Filled = TestCase:extend{
	__tag = .....".Filled",
	testSimple = function (self)
		local v = Validators.Filled()
		self.assertTrue(v:valid("1"))
		self.assertFalse(v:valid(""))
		self.assertFalse(v:valid())
		self.assertTrue(v:valid(0))
		self.assertTrue(v:valid(1))
		self.assertFalse(v:valid({}))
	end
}

local Int = TestCase:extend{
	__tag = .....".Int",
	testSimple = function (self)
		local v = Validators.Int()
		self.assertTrue(v:valid(10))
		self.assertTrue(v:valid(0))
		self.assertTrue(v:valid("10"))
		self.assertTrue(v:valid("-1"))
		self.assertFalse(v:valid(""))
		self.assertTrue(v:valid())
		self.assertFalse(v:valid(true))
		self.assertFalse(v:valid(false))
		self.assertFalse(v:valid("0.43e-23"))
	end
}

local Length = TestCase:extend{
	__tag = .....".Length",
	testSimple = function (self)
		v = Validators.Length(5, 10)
		self.assertTrue(v:valid("12345"))
		self.assertTrue(v:valid("1234567891"))
		self.assertFalse(v:valid("1234"))
		self.assertFalse(v:valid("12345678910"))
		self.assertTrue(v:valid(""))
		self.assertFalse(v:valid(10))
		self.assertTrue(v:valid())
		self.assertTrue(v:valid(10000))
		self.assertFalse(v:valid(false))
		self.assertFalse(v:valid(true))
		v = Validators.Length(0, 5)
		self.assertTrue(v:valid(""))
		self.assertTrue(v:valid("12345"))
		self.assertTrue(v:valid(12345))
		self.assertFalse(v:valid("123456"))
		self.assertFalse(v:valid(1000000))
		self.assertTrue(v:valid())
		self.assertTrue(v:valid(true))
		self.assertTrue(v:valid(false))
		v = Validators.Length(5, 0)
		self.assertFalse(v:valid "abcd")
		self.assertTrue(v:valid "abcde")
		self.assertTrue(v:valid "abcdefgh")
	end
}

local Regexp = TestCase:extend{
	__tag = .....".Regexp",
	testSimple = function (self)
		local r = Validators.Regexp"^%d%d%-%d%d%-%d%d%d%d$"
		self.assertTrue(r:valid"")
		self.assertTrue(r:valid"10-12-2005")
		self.assertFalse(r:valid"101-10-2008")
	end
}

local Value = TestCase:extend{
	__tag = .....".Value",
	testSimple = function (self)
		local v = Validators.Value"test"
		self.assertTrue(v:valid("test"))
		self.assertFalse(v:valid(""))
		self.assertFalse(v:valid())
		self.assertFalse(v:valid(false))
		self.assertFalse(v:valid(true))
		self.assertFalse(v:valid(25))
		v = Validators.Value"25"
		self.assertTrue(v:valid("25"))
		self.assertTrue(v:valid(25))
		self.assertFalse(v:valid(26))
		self.assertFalse(v:valid(""))
		self.assertFalse(v:valid())
		self.assertFalse(v:valid(false))
		self.assertFalse(v:valid(true))
		v = Validators.Value(-625)
		self.assertTrue(v:valid("-625"))
		self.assertTrue(v:valid(-625))
		self.assertFalse(v:valid(-0.26))
		self.assertFalse(v:valid(""))
		self.assertFalse(v:valid())
		self.assertFalse(v:valid(false))
		self.assertFalse(v:valid(true))
	end
}

return {
	Filled=Filled;Int=Int;Length=Length;Regexp=Regexp;Value=Value;
}
