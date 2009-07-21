local Fields, TestCase = require "luv.fields", require "luv.dev.unittest".TestCase

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
		self.assertFalse(f:required())
		self.assertFalse(f:unique())
		self.assertFalse(f:pk())
		f:value("value")
		self.assertTrue(f:value(), "value")
		self.assertEquals(f:maxLength(), 255)
	end,
	testMaxLength = function (self)
		local f = Fields.Text{maxLength = 10}
		f:value("1234567890")
		self.assertEquals(f:value(), "1234567890")
		self.assertTrue(f:valid())
		f:value("12345678901")
		self.assertFalse(f:valid())
	end,
	testMinLength = function (self)
		local f = Fields.Text{minLength = 4, maxLength = 6}
		f:value("123")
		self.assertFalse(f:valid())
		f:value("1234")
		self.assertTrue(f:valid())
		f:value("123456")
		self.assertTrue(f:valid())
		f:value("1234567")
		self.assertFalse(f:valid())
	end
}

local Login = TestCase:extend{
	__tag = .....".Login",
	testSimple = function (self)
		local l = Fields.Login()
		l:value"admin"
		self.assertTrue(l:valid())
		l:value"not_valid_pass--DROP TABLE"
		self.assertFalse(l:valid())
		l:value"valid_log.in1234"
		self.assertTrue(l:valid())
		l:value""
		self.assertFalse(l:valid())
		l:value"Too_long_login_is_not_valid_too__"
		self.assertFalse(l:valid())
		l:value"$*)&@#^&)$%@(*#$&"
		self.assertFalse(l:valid())
	end
}

local Email = TestCase:extend{
	__tag = .....".Email";
	testSimple = function (self)
		local e = Fields.Email()
		e:value "test@test.com"
		self.assertTrue(e:valid())
		e:value "test2134@test-sadf.asdfa.info"
		self.assertTrue(e:valid())
		e:value "Sfdssdf.test-2134@test-sadf.asd654fa.ru"
		self.assertTrue(e:valid())
		e:value "@test.ru"
		self.assertFalse(e:valid())
		e:value "asdf@"
		self.assertFalse(e:valid())
		e:value "asdf@#%!@#@asdf.ru"
		self.assertFalse(e:valid())
		e:value "asdf@asdf."
		self.assertFalse(e:valid())
		e:value "asdf@asd@asdf.re"
		self.assertFalse(e:valid())
		e:value "--asdfasd@asdf.re"
		self.assertFalse(e:valid())
	end;
}

return {
	Field = Field,
	Text = Text,
	Login = Login;
	Email=Email;
}
