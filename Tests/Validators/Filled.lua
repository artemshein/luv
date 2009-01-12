local TestCase, Filled = require"TestCase", require"Validators.Filled"

module(...)

local FilledTest = TestCase:extend{
	testSimple = function (self)
		local v = Filled:new()
		self.assertTrue(v:validate("1"))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertTrue(v:validate(0))
		self.assertTrue(v:validate(1))
		self.assertTrue(v:validate({}))
	end
}

return FilledTest