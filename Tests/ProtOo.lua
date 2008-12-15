local Object, UnitTest = require"ProtOo", require"UnitTest"

module(...)

local ProtOo = UnitTest:extend{
	testSimple = function (self)
		self.assertThrows(function () Object:new() end)
	end,
	testProperties = function (self)
		local A = Object:extend{
			a = 10,
			init = function (self) return self end
		}
		local obj = A:new()
		self.assertEquals(obj.a, 10)
		obj.a = 20
		self.assertEquals(obj.a, 20)
		local obj2 = A:new()
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
		local a, b = A:new(), B:new()
		self.assertTrue(a:isKindOf(A))
		self.assertTrue(a:isKindOf(Object))
		self.assertTrue(b:isKindOf(B))
		self.assertTrue(b:isKindOf(Object))
		self.assertFalse(a:isKindOf(B))
		self.assertFalse(a:isKindOf(b))
		self.assertFalse(b:isKindOf(A))
		self.assertFalse(b:isKindOf(a))
		local A2, B2 = A:extend{}, B:extend{}
		local a2, b2 = A2:new(), B2:new()
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
		local b = B:new()
		b.test = 12
		self.assertEquals(b.test, 12)
		self.assertEquals(b.parent, B)
		self.assertEquals(b.parent.test, 11)
		self.assertEquals(b.parent.parent, A)
		self.assertEquals(b.parent.parent.test, 10)
		self.assertEquals(b.parent.parent.parent, Object)
		self.assertNil(b.parent.parent.parent.parent)
	end,
	testMethodCall = function (self)
		local A = Object:extend{init = function () end, test = function () return "123" end}
		local A2 = A:extend{test = function () return "234" end}
		local A3 = A2:extend{}
		local A4 = A3:extend{}
		local a, a2, a3, a4 = A:new(), A2:new(), A3:new(), A4:new()
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
		local a, a2, a3 = A:new(), A2:new(), A3:new()
		self.assertEquals(f(a2), Object)
		self.assertEquals(f(a3), Object)
		self.assertThrows(function () f(a) end)
		f = Object.checkTypes(A3, function (obj) return obj end, A2)
		self.assertEquals(f(a3), a3)
		self.assertThrows(function() f(a2) end)
		self.assertThrows(function() f(a) end)
		self.assertThrows(function() f("abc") end)
	end
}

return ProtOo