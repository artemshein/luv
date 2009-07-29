local require = require
local table = require"luv.table"
local TestCase, keyvalue = require"luv.dev.unittest".TestCase, require"luv.db.keyvalue"

module(...)

local validDsn = "redis://localhost/8"

local Driver = TestCase:extend{
	__tag = .....".Driver";
	redis = TestCase.property;
	setUp = function (self)
		self:redis(keyvalue.Factory(validDsn))
		self:redis():flush()
	end;
	tearDown = function (self)
		self:redis():close()
	end;
	testGetSet = function (self)
		local redis = self:redis()
		self.assertNil(redis:get"testKey")
		self.assertFalse(redis:exists"testKey")
		self.assertTrue(redis:set("testKey", "testString"))
		self.assertTrue(redis:exists"testKey")
		self.assertEquals(redis:get"testKey", "testString")
		self.assertTrue(redis:set("testKey2", 133))
		self.assertEquals(redis:get"testKey2", 133)
		self.assertTrue(redis:set("testKey3", {abc={cde="efg";[1]=5;[2]=6};["key'key"]="val \"ue"}))
		self.assertEquals(redis:get"testKey3".abc.cde, "efg")
		self.assertEquals(redis:get"testKey3".abc[1], 5)
		self.assertEquals(redis:get"testKey3".abc[2], 6)
		self.assertEquals(redis:get"testKey3"["key'key"], "val \"ue")
	end;
	testMultiGetSet = function (self)
		local redis = self:redis()
		redis:set({abc=123;cde="hello";def={1;4;9;16;25}})
		local values = redis:get{"abc";"cde";"def"}
		self.assertEquals(values.abc, 123)
		self.assertEquals(values.cde, "hello")
		self.assertEquals(values.def[1], 1)
		self.assertEquals(values.def[2], 4)
		self.assertEquals(values.def[3], 9)
		self.assertEquals(values.def[4], 16)
		self.assertEquals(values.def[5], 25)
	end;
	testIncrDecr = function (self)
		local redis = self:redis()
		redis:incr"ttt"
		self.assertEquals(redis:get"ttt", 1)
		redis:incr"ttt"
		self.assertEquals(redis:get"ttt", 2)
		redis:incr("ttt", 5)
		self.assertEquals(redis:get"ttt", 7)
		redis:decr"ttt"
		self.assertEquals(redis:get"ttt", 6)
		redis:decr("ttt", 8)
		self.assertEquals(redis:get"ttt", -2)
	end;
	testKeys2 = function (self)
		local redis = self:redis()
		self.assertTrue(table.isEmpty(redis:keys"*"))
		redis:set{abc=123;cde=425;efg=678;aff=124}
		self.assertEquals(#redis:keys"*", 4)
		self.assertEquals(#redis:keys"a*", 2)
	end;
	testRename = function (self)
		local redis = self:redis()
		redis:set("key", "value")
		self.assertNil(redis:get"key2")
		redis:rename("key", "key2")
		self.assertEquals(redis:get"key2", "value")
	end;
	testList = function (self)
		local redis = self:redis()
		self.assertFalse(redis:exists"k")
		redis:rpush("k", "abc")
		redis:rpush("k", 123)
		redis:lpush("k", {a=1;b=2;c=3})
		self.assertEquals(redis:llen"k", 3)
		redis:lpush("k", false)
		self.assertEquals(redis:llen"k", 4)
		self.assertTrue(#redis:lrange("k", 0, 3), 4)
		self.assertEquals(redis:lrange("k", 0, 3)[1], false)
		self.assertEquals(redis:lindex("k", 0), false)
		self.assertEquals(redis:lindex("k", -4), false)
		self.assertEquals(redis:lindex("k", 1).a, 1)
		self.assertEquals(redis:lindex("k", -3).a, 1)
		self.assertEquals(redis:lrange("k", 0, 3)[2].a, 1)
		self.assertEquals(redis:lrange("k", 0, 3)[2].b, 2)
		self.assertEquals(redis:lrange("k", 0, 3)[2].c, 3)
		self.assertEquals(redis:lindex("k", 2), "abc")
		self.assertEquals(redis:lindex("k", -2), "abc")
		self.assertEquals(redis:lrange("k", 0, 3)[3], "abc")
		self.assertEquals(redis:lindex("k", 3), 123)
		self.assertEquals(redis:lindex("k", -1), 123)
		self.assertEquals(redis:lrange("k", 0, 3)[4], 123)
		self.assertTrue(#redis:lrange("k", 0, 1), 2)
		self.assertTrue(#redis:lrange("k", -1, -4), 4)
		redis:lset("k", 1, nil)
		self.assertNil(redis:lindex("k", 1))
		redis:lrem("k", 0, "abc")
		require"luv.dev".dprint(redis:llen"k")
		self.assertEquals(redis:llen"k", 3)
		self.assertEquals(redis:lpop"k", false)
		self.assertEquals(redis:rpop"k", 123)
		self.assertEquals(redis:lpop"k", nil)
		self.assertEquals(redis:llen"k", 0)
		
		for i = 1, 20 do
			redis:rpush("k", i)
		end
		self.assertEquals(redis:llen"k", 20)
		redis:ltrim("k", 0, 9)
		self.assertEquals(redis:llen"k", 10)
	end;
}

return {Driver=Driver}
