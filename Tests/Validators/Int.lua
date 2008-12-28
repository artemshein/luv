local TestCase, Int = require"TestCase", require"Validators.Int"

module(...)

local IntTest = TestCase:extend{
	testSimple = function (self)
		local v = Int:new()
		self.assertTrue(v:validate(10))
		self.assertTrue(v:validate(0))
		self.assertTrue(v:validate("10"))
		self.assertTrue(v:validate("-1"))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertFalse(v:validate(true))
		self.assertFalse(v:validate(false))
		self.assertTrue(v:validate("0.43e-23"))
	end
}

return IntTest