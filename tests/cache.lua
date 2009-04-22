local debug = require "luv.debug"
local cache = require "luv.cache.backend"
local TestCase = require "luv.unittest".TestCase

module(...)

local Memcached = TestCase:extend{
	__tag = .....".Memcached";
	setUp = function (self)
		self.memcached = cache.Memcached()
		self.memcached:clear()
	end;
	tearDown = function (self)
		self.memcached:clear()
	end;
	testGetSet = function (self)
		local m = self.memcached
		m:set("testKey", 5)
		self.assertEquals(m:get "testKey", 5)
		m:set("testKey", "hello")
		self.assertEquals(m:get "testKey", "hello")
		m:set("testKey", false)
		self.assertEquals(m:get "testKey", false)
		m:set("testKey", nil)
		self.assertNil(m:get "testKey")
		m:set("testKey", {a={10;false};["abc"]={"ef";["da"]=144}})
		self.assertEquals(m:get "testKey".a[1], 10)
		self.assertEquals(m:get "testKey".a[2], false)
		self.assertNil(m:get "testKey".a[3])
		self.assertEquals(m:get "testKey".abc[1], "ef")
		self.assertEquals(m:get "testKey".abc.da, 144)
		local str = [[multiple
		lines
		string]]
		m:set("testKey", str)
		self.assertEquals(m:get "testKey", str)
	end;
	testNamespaceWrapper = function (self)
		local one, two = cache.NamespaceWrapper(self.memcached, "One"), cache.NamespaceWrapper(self.memcached, "Two")
		one:set("key", 55)
		two:set("key", 66)
		self.assertEquals(one:get "key", 55)
		self.assertEquals(two:get "key", 66)
	end;
	testTagEmuWrapper = function (self)
		local m = cache.TagEmuWrapper(self.memcached)
		m:set("key", "value", {"tag1";"tag2"})
		self.assertEquals(m:get "key", "value")
		m:clearTags {"tag1"}
		self.assertNil(m:get "key")
	end;
	testMultipleKeys = function (self)
		local m = cache.NamespaceWrapper(cache.TagEmuWrapper(self.memcached), "testNamespace")
		m:set("key1", "value1", {"tag1";"tag2"})
		m:set("key2", "value2", {"tag1"})
		m:set("key3", "value3")
		self.assertEquals(m:get("key1", "key2", "key3").key1, "value1")
		self.assertEquals(m:get("key1", "key2", "key3").key2, "value2")
		self.assertEquals(m:get("key1", "key2", "key3").key3, "value3")
		m:clearTags{"tag1"}
		self.assertNil(m:get "key1")
		self.assertNil(m:get "key2")
		self.assertEquals(m:get ("key1", "key2", "key3").key3, "value3")
	end;
}

return {Memcached=Memcached}
