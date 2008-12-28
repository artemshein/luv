local TestCase, Login = require"TestCase", require"Fields.Login"

module(...)

local LoginTest = TestCase:extend{
	__tag = "Tests.Fields.Login",
	
	testSimple = function (self)
		local l = Login:new()
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

return LoginTest