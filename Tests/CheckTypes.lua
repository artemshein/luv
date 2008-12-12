local UnitTest, CheckTypes = require"UnitTest", require"CheckTypes"
local checkTypes, type, tostring, tonumber, io = CheckTypes.checkTypes, type, tostring, tonumber, io

module(...)

local CheckTypesTest = UnitTest:extend{
	testSimple = function (self)
		local a = checkTypes("number", function (num) return num+1 end, "number")
		self.assertThrows(function () a("abc") end)
		self.assertEquals(a(10), 11)
	end,
	testManyParams = function (self)
		local a = checkTypes(
			"number", "string", "table", "nil", "boolean",
			function ()
				return function () end, 10, "ccc", false 
			end,
			"function", "number", "string", "boolean"
		)
		local f, n, s, b = a(10, "", {}, nil, true)
		self.assertEquals(type(f), "function")
		self.assertEquals(n, 10)
		self.assertEquals(s, "ccc")
		self.assertEquals(b, false)
		self.assertThrows(function () a() end)
		self.assertThrows(function () a("123") end)
		self.assertThrows(function () a(123, false) end)
		self.assertThrows(function () a(123, "cvv", 25) end)
		self.assertThrows(function () a(123, "cvv", {a = 5}) end)
		self.assertThrows(function () a(123, "cvv", {a = 5}, false, function () end) end)
		self.assertThrows(function () a(false, "cvv", {a = 5}, function () end, true) end)
		self.assertThrows(function () a(123, {}, {a = 5}, "asdas", true) end)
		self.assertThrows(function () a(123, "aaa", nil, 12, true) end)
		a(123, "aaa", {}, true, true)
		a(123, "aaa", {}, nil, true)
		a(123, "aaa", {}, -15, true)
		a(123, "aaa", {}, {}, true)
		a(123, "aaa", {}, "bool", true)
	end,
	testInvalidReturnType = function (self)
		local a = checkTypes(function () return 123 end, "string")
		self.assertThrows(function () a() end)
		a = checkTypes("number", function (n) return tostring(n) end, "string")
		self.assertEquals(a(125), "125")
		a = checkTypes("string", function (s) return tonumber(s) end, "number")
		self.assertEquals(a("1443"), 1443)
		self.assertThrows(function () a("not a number") end)
	end
}

return CheckTypesTest