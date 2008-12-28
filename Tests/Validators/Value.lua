local TestCase, Value = require"TestCase", require"Validators.Value"

module(...)

local ValueTest = TestCase:extend{
	testSimple = function (self)
		local v = Value:new"test"
		self.assertTrue(v:validate("test"))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertFalse(v:validate(false))
		self.assertFalse(v:validate(true))
		self.assertFalse(v:validate(25))
		v = Value:new"25"
		self.assertTrue(v:validate("25"))
		self.assertTrue(v:validate(25))
		self.assertFalse(v:validate(26))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertFalse(v:validate(false))
		self.assertFalse(v:validate(true))
		v = Value:new(-0.25)
		self.assertTrue(v:validate("-0.25"))
		self.assertTrue(v:validate(-0.25))
		self.assertFalse(v:validate(-0.26))
		self.assertFalse(v:validate(""))
		self.assertFalse(v:validate())
		self.assertFalse(v:validate(false))
		self.assertFalse(v:validate(true))
	end
}

return ValueTest