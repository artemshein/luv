local TestCase, Tamplier, fs = require "luv.dev.unittest".TestCase, require "luv.templaters.tamplier", require "luv.fs"
local File = fs.File

module(...)

return TestCase:extend{
	__tag = ...,
	testFileName = "/tmp/fgasu2345sfafasdf",
	setUp = function (self)
		self.t = Tamplier()
	end,
	tearDown = function (self)
		self.t = nil
	end,
	testSimpleText = function (self)
		local test = [[T~~@est st_3245ring
		with new l%in-()es{ } { % %% }\}]]
		self.assertEquals(test, self.t:fetchString(test))
	end,
	testSimpleVars = function (self)
		self.t:assign("abc", 10)
		self.t:assign("str", "string - string - string")
		self.assertEquals("abc: 10, str: string - string - string", self.t:fetchString("abc: {{abc}}, str: {{str}}"))
	end,
	testTable = function (self)
		self.t:assign("tbl", {a = 10, b = 20, c = "30"})
		self.assertEquals("tbl {a = 10, b = 20, c = 30}", self.t:fetchString("tbl {a = {{tbl.a}}, b = {{tbl.b}}, c = {{tbl.c}}}"))
	end,
	testSimpleExpression = function (self)
		self.t:assign("a", 25)
		self.t:assign("b", 50)
		self.assertEquals("75", self.t:fetchString("{{a+b}}"))
	end,
	testFor = function (self)
		self.assertEquals("12345678910", self.t:fetchString("{% for i = 1, 10 do %}{{i}}{% end %}"))
	end,
	testInclude = function (self)
		local f = File:new(self.testFileName):openForWriting():write("included text"):close()
		self.assertEquals("local text, included text", self.t:fetchString("local text, {{include(\""..self.testFileName.."\")}}"))
		f:delete()
	end,
	testIncludeWithVars = function (self)
		local f = File:new(self.testFileName):openForWriting():write("{{a+b}}"):close()
		self.t:assign{a = 10, b = 20}
		self.assertEquals("value = 30", self.t:fetchString("value = {{include(\""..self.testFileName.."\")}}"))
		self.assertEquals("value = 30", self.t:fetchString("value = {% val = include(\""..self.testFileName.."\") %}{{val}}"))
		f:delete()
	end
}
