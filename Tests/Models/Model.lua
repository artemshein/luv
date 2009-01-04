local TestCase, Model, Char, Debug = require"TestCase", require"Models.Model", require"Fields.Char", require"Debug"
local getmetatable, io = getmetatable, io

module(...)

return TestCase:extend{
	__tag = "Tests.Models.Model",

	testAbstract = function (self)
		self.assertThrows(function () Model:new() end)
	end,
	testBasic = function (self)
		local Test = Model:extend{
			__tag = "Models.Test",
			fields = {test = Char:new{minLength = 4, maxLength = 6}}
		}
		local t = Test:new()
		t.test = "123"
		self.assertEquals(t.test, "123")
		self.assertEquals(t.test, t:getField"test":getValue())
		self.assertEquals(t:getField"test":getName(), "test")
		self.assertFalse(t:validate())
		t.test = "1234"
		self.assertTrue(t:validate())
		local t2 = t:clone()
		t2:getField"test":setName"test2"
		self.assertNotNil(t:getField"test")
		self.assertNil(t:getField"test2")
		self.assertNil(t2:getField"test")
		self.assertNotNil(t2:getField"test2")
	end
}
