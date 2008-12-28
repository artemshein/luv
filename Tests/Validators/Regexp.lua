local TestCase, Regexp = require"TestCase", require"Validators.Regexp"

module(...)

local RegexpTest = TestCase:extend{
	__tag = "Tests.Validators.Regexp",
	
	testSimple = function (self)
		local r = Regexp:new"^%d%d%-%d%d%-%d%d%d%d$"
		self.assertFalse(r:validate"")
		self.assertTrue(r:validate"10-12-2005")
		self.assertFalse(r:validate"101-10-2008")
	end
}

return RegexpTest