local TestCase, InputField, Char = require"TestCase", require"Widgets.InputField", require"Fields.Char"

module(...)

local InputFieldTest = TestCase:extend{
	__tag = "Tests.Widgets.InputField",
	
	testSimple = function (self)
		local c = Char:new{
			name = "test",
			htmlWidget = InputField:new()
		}
		self.assertEquals(c:asHtml(), [[<input type="text" name="test" value="" />]])
		c = Char:new{
			name = "test",
			defaultValue = [[abc"def']],
			htmlWidget = InputField:new"hidden"
		}
		self.assertEquals(c:asHtml(), [[<input type="hidden" name="test" value="abc&quot;def'" />]])
	end
}

return InputFieldTest