require"luv.debug"
local getmetatable, debug = getmetatable, debug
local Object, TestCase = require"luv.oop".Object, require"luv.unittest".TestCase

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
		self.assertTrue(Object:isKindOf(Object))
		local A, B = Object:extend{init = function (self) return self end}, Object:extend{init = function (self) return self end}
		self.assertTrue(A:isKindOf(Object))
		self.assertTrue(B:isKindOf(Object))
		self.assertFalse(A:isKindOf(B))
		self.assertFalse(B:isKindOf(A))
		local a, b = A(), B()
		self.assertTrue(a:isKindOf(A))
		self.assertTrue(a:isKindOf(Object))
		self.assertTrue(b:isKindOf(B))
		self.assertTrue(b:isKindOf(Object))
		self.assertFalse(a:isKindOf(B))
		self.assertFalse(a:isKindOf(b))
		self.assertFalse(b:isKindOf(A))
		self.assertFalse(b:isKindOf(a))
		local A2, B2 = A:extend{}, B:extend{}
		local a2, b2 = A2(), B2()
		self.assertTrue(a2:isKindOf(A2))
		self.assertTrue(a2:isKindOf(A))
		self.assertTrue(a2:isKindOf(Object))
		self.assertTrue(b2:isKindOf(B2))
		self.assertTrue(b2:isKindOf(B))
		self.assertTrue(b2:isKindOf(Object))
		self.assertFalse(a2:isKindOf(B2))
		self.assertFalse(a2:isKindOf(b2))
		self.assertFalse(b2:isKindOf(A2))
		self.assertFalse(b2:isKindOf(a2))
		self.assertTrue(a2:isKindOf(a2))
		self.assertTrue(b2:isKindOf(b2))
	end,
	testParent = function (self)
		local A = Object:extend{init = function (self) return self end, test = 10}
		local B = A:extend{test = 11}
		local b = B()
		b.test = 12
		self.assertEquals(b.test, 12)
		self.assertEquals(b.parent, B)
		self.assertEquals(b.parent.test, 11)
		self.assertEquals(b.parent.parent, A)
		self.assertEquals(b.parent.parent.test, 10)
		self.assertEquals(b.parent.parent.parent, Object)
		self.assertNil(b.parent.parent.parent.parent)
	end,
	testClone = function (self)
		local A = Object:extend{init = function () end}
		local a = A()
		local b = a:clone()
		self.assertNotEquals(a, b)
		self.assertEquals(a.parent, b.parent)
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
	testCheckTypes = function (self)
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
	end,
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
	end
}
