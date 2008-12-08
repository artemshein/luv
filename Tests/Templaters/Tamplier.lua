local UnitTest, Tamplier, File = require"UnitTest", require"Templaters.Tamplier", require"File"

module(...)

local TamplierTest = UnitTest:extend{
	testFileName = "fgasu2345sfafasdf",
	
	setUp = function (self)
		self.t = Tamplier:new()
	end,

	tearDown = function (self)
		self.t = nil
	end,

	testSimpleText = function (self)
		local test = [[T~~@est st_3245ring
		with new l%in-()es{ } { % %% }\}]]
		assertEquals(test, t:fetchString(test))
	end,

	testSimpleVars = function (self)
		t:assign("abc", 10)
		t:assign("str", "string - string - string")
		assertEquals("abc: 10, str: string - string - string", t:fetchString("abc: {{abc}}, str: {{str}}"))
	end,

	testTable = function (self)
		t:assign("tbl", {a = 10, b = 20, c = "30"})
		assertEquals("tbl {a = 10, b = 20, c = 30}", t:fetchString("tbl {a = {{tbl.a}}, b = {{tbl.b}}, c = {{tbl.c}}}"))
	end,

	testSimpleExpression = function (self)
		t:assign("a", 25)
		t:assign("b", 50)
		assertEquals("75", t:fetchString("{{a+b}}"))
	end,

	testFor = function (self)
		assertEquals("12345678910", t:fetchString("{% for i = 1, 10 do %}{{i}}{% end %}"))
	end,

	testInclude = function (self)
		local f = File:new(testFileName):openForWriting():write("included text"):close()
		assertEquals("local text, included text", t:fetchString("local text, {{include(\""..testFileName.."\")}}"))
		f:delete()
	end,

	testIncludeWithVars = function (self)
		local f = File:new(testFileName):openForWriting():write("{{a+b}}"):close()
		t:assign{a = 10, b = 20}
		assertEquals("value = 30", t:fetchString("value = {{include(\""..testFileName.."\")}}"))
		assertEquals("value = 30", t:fetchString("value = {% val = include(\""..testFileName.."\") %}{{val}}"))
		f:delete()
	end
}

return TamplierTest