local getmetatable, require = getmetatable, require
local Object, TestCase = require "luv.oop".Object, require "luv.dev.unittest".TestCase

module(...)

return TestCase:extend{
	__tag = ...,
	testSimple = function (self)
		self.assertThrows(function () Object() end)
	end,
	testProperties = function (self)
		local A = Object:extend{
			a = 10,
			init = function (self) return self end
		}
		local obj = A()
		self.assertEquals(obj.a, 10)
		obj.a = 20
		self.assertEquals(obj.a, 20)
		local obj2 = A()
		self.assertEquals(obj2.a, 10)
		self.assertEquals(obj.a, 20)
	end,
	testIsKindOf = function (self)
		self.assertTrue(Object:isA(Object))
		local A, B = Object:extend{init = function (self) return self end}, Object:extend{init = function (self) return self end}
		self.assertTrue(A:isA(Object))
		self.assertTrue(B:isA(Object))
		self.assertFalse(A:isA(B))
		self.assertFalse(B:isA(A))
		local a, b = A(), B()
		self.assertTrue(a:isA(A))
		self.assertTrue(a:isA(Object))
		self.assertTrue(b:isA(B))
		self.assertTrue(b:isA(Object))
		self.assertFalse(a:isA(B))
		self.assertFalse(a:isA(b))
		self.assertFalse(b:isA(A))
		self.assertFalse(b:isA(a))
		local A2, B2 = A:extend{}, B:extend{}
		local a2, b2 = A2(), B2()
		self.assertTrue(a2:isA(A2))
		self.assertTrue(a2:isA(A))
		self.assertTrue(a2:isA(Object))
		self.assertTrue(b2:isA(B2))
		self.assertTrue(b2:isA(B))
		self.assertTrue(b2:isA(Object))
		self.assertFalse(a2:isA(B2))
		self.assertFalse(a2:isA(b2))
		self.assertFalse(b2:isA(A2))
		self.assertFalse(b2:isA(a2))
		self.assertTrue(a2:isA(a2))
		self.assertTrue(b2:isA(b2))
	end,
	testParent = function (self)
		local A = Object:extend{init = function (self) return self end, test = 10}
		local B = A:extend{test = 11}
		local b = B()
		b.test = 12
		self.assertEquals(b.test, 12)
		self.assertEquals(b:parent(), B)
		self.assertEquals(b:parent().test, 11)
		self.assertEquals(b:parent():parent(), A)
		self.assertEquals(b:parent():parent().test, 10)
		self.assertEquals(b:parent():parent():parent(), Object)
		self.assertNil(b:parent():parent():parent():parent())
	end,
	testClone = function (self)
		local A = Object:extend{init = function () end}
		local a = A()
		local b = a:clone()
		self.assertNotEquals(a, b)
		self.assertEquals(a:parent(), b:parent())
		self.assertEquals(getmetatable(a), getmetatable(b))
	end,
	testMethodCall = function (self)
		local A = Object:extend{init = function () end, test = function () return "123" end}
		local A2 = A:extend{test = function () return "234" end}
		local A3 = A2:extend{}
		local A4 = A3:extend{}
		local a, a2, a3, a4 = A(), A2(), A3(), A4()
		self.assertEquals(a:test(), "123")
		self.assertEquals(a2:test(), "234")
		self.assertEquals(a3:test(), "234")
		self.assertEquals(a4:test(), "234")
		A3.test = function () return "345" end
		self.assertEquals(a3:test(), "345")
		self.assertEquals(a4:test(), "345")
	end,
	--[[testCheckTypes = function (self)
		local A = Object:extend{init = function () end}
		local A2 = A:extend{}
		local A3 = A2:extend{}
		local f = Object.checkTypes(A2, function () return Object end, Object)
		local a, a2, a3 = A(), A2(), A3()
		self.assertEquals(f(a2), Object)
		self.assertEquals(f(a3), Object)
		self.assertThrows(function () f(a) end)
		f = Object.checkTypes(A3, function (obj) return obj end, A2)
		self.assertEquals(f(a3), a3)
		self.assertThrows(function() f(a2) end)
		self.assertThrows(function() f(a) end)
		self.assertThrows(function() f("abc") end)
	end,]]
	testMetamethods = function (self)
		-- Test __add
		local A = Object:extend{
			init = function (self) self.a = 5 end,
			__add = function (self, second)
				local newObj = self:clone()
				newObj.a = newObj.a + second.a
				return newObj
			end
		}
		local a, b = A(), A()
		self.assertEquals(a.a, 5)
		self.assertEquals(b.a, 5)
		local c = a+b
		self.assertEquals(c.a, 10)
		-- Test __call
		local A = Object:extend{
			init = function (self)
				self.a = function (param1, param2) return param1+param2 end
			end,
			__call = function (self, ...)
				return self.a(...)
			end
		}
		local a = A:new()
		self.assertEquals(a(5, 10), 15)
		-- Test __len
		--[[ FIXME: Doesn't work, don't know why
		local A = Object:extend{
			init = function (self) self.a = {1, 2, 3, 4, 5} end,
			__len = function (self) io.write"From __len!" return #(self.a) end
		}
		local a = A:new()
		Debug.dump(A, 3)
		self.assertEquals(#a, 5)
		a.a = {1, 2, 3}
		self.assertEquals(#a, 3)]]
	end;
	testProperties = function (self)
		local A = Object:extend{
			a = Object.property;
			_b = 25;
			b = Object.property;
			init = function () end;
		}
		self.assertNil(A:a())
		self.assertEquals(A:b(), 25)
		local a = A()
		self.assertNil(a:a())
		self.assertEquals(a:b(), 25)
		a:a(10)
		self.assertNil(A:a())
		self.assertEquals(a:a(), 10)
		a:b(20)
		self.assertEquals(A:b(), 25)
		self.assertEquals(a:b(), 20)
		a:b(nil)
		self.assertEquals(A:b(), 25)
		self.assertEquals(a:b(), 25)
	end;
	testTypedProperties = function (self)
		local A = Object:extend{}
		local B = Object:extend{
			a = Object.property(A);
			_str = "hello";
			str = Object.property "string";
			_num = 10;
			num = Object.property "number";
			init = function () end;
		}
		local b = B()
		self.assertEquals(b:str(), "hello")
		self.assertEquals(b:num(), 10)
		self.assertThrows(function () b:str(101) end)
		self.assertThrows(function () b:num "nan" end)
		self.assertThrows(function () b:num{} end)
		self.assertThrows(function () b:str(nil) end)
		b:str "hi"
		self.assertEquals(b:str(), "hi")
		b:num(23)
		self.assertEquals(b:num(), 23)
		self.assertEquals(B:str(), "hello")
		self.assertEquals(B:num(), 10)
	end;
}
