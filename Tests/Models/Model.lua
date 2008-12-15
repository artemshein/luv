local UnitTest, Model, Char, Debug = require"UnitTest", require"Models.Model", require"Fields.Char", require"Debug"
local getmetatable, io = getmetatable, io

module(...)

local ModelTest = UnitTest:extend{
	testAbstract = function (self)
		self.assertThrows(function () Model:new() end)
	end,
	testModel = function (self)
		local Test = Model:extend{
			__tag = "Models.Test",
			init = function (self)
				self.fields = {test = Char:new{minLength = 4, maxLength = 6}}
			end
		}
		local t = Test:new()
		t.test = "123"
		self.assertEquals(t.test, "123")
		self.assertEquals(t.test, t:getField("test"):getValue())
		self.assertFalse(t:validate())
		t.test = "1234"
		self.assertTrue(t:validate())
		--Debug.dump(t)
	end
}

return ModelTest