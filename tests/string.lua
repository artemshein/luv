local string = require "luv.string"
local io = io
local TestCase = require "luv.dev.unittest".TestCase

module(...)

return TestCase:extend{
	__tag = ...,
	testSlice = function (self)
		self.assertEquals(string.slice("1234567890", 1), "1234567890")
		self.assertEquals(string.slice("1234567890", -1), "0")
		self.assertEquals(string.slice("1234567890", 2), "234567890")
		self.assertEquals(string.slice("1234567890", -2), "90")
		self.assertEquals(string.slice("1234567890", 5), "567890")
		self.assertEquals(string.slice("1234567890", -5), "67890")
		self.assertEquals(string.slice("1234567890", 1, 9), "123456789")
		self.assertEquals(string.slice("1234567890", 1, 10), "1234567890")
		self.assertEquals(string.slice("1234567890", 2, 5), "2345")
		self.assertEquals(string.slice("1234567890", 2, -1), "234567890")
		self.assertEquals(string.slice("1234567890", 4, -5), "456")
		self.assertEquals(string.slice("1234567890", 7, -3), "78")
		self.assertEquals(string.slice("1234567890", -22), "1234567890")
		self.assertEquals(string.slice("1234567890", 12), "")
	end,
	testSplit = function (self)
		local http, user, pass, domain, zone, url, section, get, params = string.split("http://user:pass@domain.zone/url#section?get=params", "://", ":", "@", ".", "/", "#", "?", "=")
		self.assertEquals(http, "http")
		self.assertEquals(user, "user")
		self.assertEquals(pass, "pass")
		self.assertEquals(domain, "domain")
		self.assertEquals(zone, "zone")
		self.assertEquals(url, "url")
		self.assertEquals(section, "section")
		self.assertEquals(get, "get")
		self.assertEquals(params, "params")
		local http, domainFull, url, params = string.split("http://user:pass@domain.zone/url", "://", "/", "?")
		self.assertEquals(http, "http")
		self.assertEquals(domainFull, "user:pass@domain.zone")
		self.assertEquals(url, "url")
		self.assertNil(params)
	end,
	testExplode = function (self)
		local a = string.explode("first second third fourth", " ")
		self.assertEquals(a[1], "first")
		self.assertEquals(a[2], "second")
		self.assertEquals(a[3], "third")
		self.assertEquals(a[4], "fourth")
		self.assertNil(a[5])
		a = string.explode("dsv~+#uash;efgba~+#svbz", "~+#")
		self.assertEquals(a[1], "dsv")
		self.assertEquals(a[2], "uash;efgba")
		self.assertEquals(a[3], "svbz")
		self.assertNil(a[4])
	end,
	testCapitalize = function (self)
		self.assertEquals(string.capitalize("abc"), "Abc")
		self.assertEquals(string.capitalize("1bc"), "1bc")
		self.assertEquals(string.capitalize("Gbc"), "Gbc")
		self.assertEquals(string.capitalize("z"), "Z")
	end
}
