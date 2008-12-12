local UnitTest, Filled = require"UnitTest", require"Validators.Filled"

module(...)

local FilledTest = UnitTest:extend{
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