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
		local f = Fields.Text()
		self.assertFalse(f:isRequired())
		self.assertFalse(f:isUnique())
		self.assertFalse(f:isPk())
		f:setValue("value")
		self.assertTrue(f:getValue(), "value")
		self.assertEquals(f:getMaxLength(), 255)
	end,
	testMaxLength = function (self)
		local f = Fields.Text{maxLength = 10}
		f:setValue("1234567890")
		self.assertEquals(f:getValue(), "1234567890")
		self.assertTrue(f:isValid())
		f:setValue("12345678901")
		self.assertFalse(f:isValid())
	end,
	testMinLength = function (self)
		local f = Fields.Text{minLength = 4, maxLength = 6}
		f:setValue("123")
		self.assertFalse(f:isValid())
		f:setValue("1234")
		self.assertTrue(f:isValid())
		f:setValue("123456")
		self.assertTrue(f:isValid())
		f:setValue("1234567")
		self.assertFalse(f:isValid())
	end
}

local Login = TestCase:extend{
	__tag = .....".Login",
	testSimple = function (self)
		local l = Fields.Login()
		l:setValue"admin"
		self.assertTrue(l:isValid())
		l:setValue"not_valid_pass--DROP TABLE"
		self.assertFalse(l:isValid())
		l:setValue"valid_log.in1234"
		self.assertTrue(l:isValid())
		l:setValue""
		self.assertFalse(l:isValid())
		l:setValue"Too_long_login_is_not_valid_too__"
		self.assertFalse(l:isValid())
		l:setValue"$*)&@#^&)$%@(*#$&"
		self.assertFalse(l:isValid())
	end
}

local Email = TestCase:extend{
	__tag = .....".Email";
	testSimple = function (self)
		local e = Fields.Email()
		e:setValue "test@test.com"
		self.assertTrue(e:isValid())
		e:setValue "test2134@test-sadf.asdfa.info"
		self.assertTrue(e:isValid())
		e:setValue "Sfdssdf.test-2134@test-sadf.asd654fa.ru"
		self.assertTrue(e:isValid())
		e:setValue "@test.ru"
		self.assertFalse(e:isValid())
		e:setValue "asdf@"
		self.assertFalse(e:isValid())
		e:setValue "asdf@#%!@#@asdf.ru"
		self.assertFalse(e:isValid())
		e:setValue "asdf@asdf."
		self.assertFalse(e:isValid())
		e:setValue "asdf@asd@asdf.re"
		self.assertFalse(e:isValid())
		e:setValue "--asdfasd@asdf.re"
		self.assertFalse(e:isValid())
	end;
}

return {
	Field = Field,
	Text = Text,
	Login = Login;
	Email=Email;
}
