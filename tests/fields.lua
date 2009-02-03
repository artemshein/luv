local Fields, TestCase = require"luv.fields", require"luv.unittest".TestCase

module(...)

local Field = TestCase:extend{
	__tag = .....".Field",
	testAbstract = function (self)
		self.assertThrows(function () Fields.Field() end)
	end
}

local Char = TestCase:extend{
	__tag = .....".Char",
	testSimple = function (self)
		local f = Fields.Char()
		self.assertFalse(f:isRequired())
		self.assertFalse(f:isUnique())
		self.assertFalse(f:isPk())
		f:setValue("value")
		self.assertTrue(f:getValue(), "value")
		self.assertEquals(f:getMaxLength(), 255)
	end,
	testMaxLength = function (self)
		local f = Fields.Char{maxLength = 10}
		f:setValue("1234567890")
		self.assertEquals(f:getValue(), "1234567890")
		self.assertTrue(f:validate())
		f:setValue("12345678901")
		self.assertFalse(f:validate())
	end,
	testMinLength = function (self)
		local f = Fields.Char{minLength = 4, maxLength = 6}
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

local Login = TestCase:extend{
	__tag = .....".Login",
	testSimple = function (self)
		local l = Fields.Login()
		l:setValue"admin"
		self.assertTrue(l:validate())
		l:setValue"not_valid_pass--DROP TABLE"
		self.assertFalse(l:validate())
		l:setValue"valid_log.in1234"
		self.assertTrue(l:validate())
		l:setValue""
		self.assertFalse(l:validate())
		l:setValue"Too_long_login_is_not_valid_too__"
		self.assertFalse(l:validate())
		l:setValue"$*)&@#^&)$%@(*#$&"
		self.assertFalse(l:validate())
	end
}

return {
	Field = Field,
	Char = Char,
	Login = Login
}
