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
		self.assertTrue(redis:set("testKey", "testString"))
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
	--testKeys2 = function (self)
		--local redis = self:redis()
		--self.assertTrue(table.isEmpty(redis:keys"*"))
		--redis:set{abc=123;cde=425;efg=678;aff=124}
		--self.assertEquals(#redis:keys"*", 4)
		--self.assertEquals(#redis:keys"a", 2)
	--end;
}

return {Driver=Driver}
