local string = require "luv.string"
local dev = require "luv.dev"
local TestCase = require "luv.dev.unittest".TestCase

module(...)

return TestCase:extend{
	__tag = ...,
	testSlice = function (self)
		self.assertEquals(("1234567890"):slice(1), "1234567890")
		self.assertEquals(("1234567890"):slice(-1), "0")
		self.assertEquals(("1234567890"):slice(2), "234567890")
		self.assertEquals(("1234567890"):slice(-2), "90")
		self.assertEquals(("1234567890"):slice(5), "567890")
		self.assertEquals(("1234567890"):slice(-5), "67890")
		self.assertEquals(("1234567890"):slice(1, 9), "123456789")
		self.assertEquals(("1234567890"):slice(1, 10), "1234567890")
		self.assertEquals(("1234567890"):slice(2, 5), "2345")
		self.assertEquals(("1234567890"):slice(2, -1), "234567890")
		self.assertEquals(("1234567890"):slice(4, -5), "456")
		self.assertEquals(("1234567890"):slice(7, -3), "78")
		self.assertEquals(("1234567890"):slice(-22), "1234567890")
		self.assertEquals(("1234567890"):slice(12), "")
		-- UTF-8
		self.assertEquals(("Привет, Мир!"):slice(9), "Мир!")
		self.assertEquals(("Привет, Мир!"):slice(9, -2), "Мир")
		self.assertEquals(("Привет, Мир!"):slice(1, 6), "Привет")
	end;
	testSplit = function (self)
		local http, user, pass, domain, zone, url, section, get, params = ("http://user:pass@domain.zone/url#section?get=params"):split("://", ":", "@", ".", "/", "#", "?", "=")
		self.assertEquals(http, "http")
		self.assertEquals(user, "user")
		self.assertEquals(pass, "pass")
		self.assertEquals(domain, "domain")
		self.assertEquals(zone, "zone")
		self.assertEquals(url, "url")
		self.assertEquals(section, "section")
		self.assertEquals(get, "get")
		self.assertEquals(params, "params")
		local http, domainFull, url, params = ("http://user:pass@domain.zone/url"):split("://", "/", "?")
		self.assertEquals(http, "http")
		self.assertEquals(domainFull, "user:pass@domain.zone")
		self.assertEquals(url, "url")
		self.assertNil(params)
		-- UTF-8
		local a, b, c = ("Привет, Мир!"):split("и", "Ми")
		self.assertEquals(a, "Пр")
		self.assertEquals(b, "вет, ")
		self.assertEquals(c, "р!")
	end;
	testExplode = function (self)
		local a = ("first second third fourth"):explode" "
		self.assertEquals(a[1], "first")
		self.assertEquals(a[2], "second")
		self.assertEquals(a[3], "third")
		self.assertEquals(a[4], "fourth")
		self.assertNil(a[5])
		a = ("dsv~+#uash;efgba~+#svbz"):explode"~+#"
		self.assertEquals(a[1], "dsv")
		self.assertEquals(a[2], "uash;efgba")
		self.assertEquals(a[3], "svbz")
		self.assertNil(a[4])
		-- UTF-8
		local a = ("Привет, и Мир! и Пыщь!!!11"):explode" и "
		self.assertEquals(a[1], "Привет,")
		self.assertEquals(a[2], "Мир!")
		self.assertEquals(a[3], "Пыщь!!!11")
		self.assertNil(a[4])
	end;
	testCapitalize = function (self)
		self.assertEquals(("abc"):capitalize(), "Abc")
		self.assertEquals(("1bc"):capitalize(), "1bc")
		self.assertEquals(("Gbc"):capitalize(), "Gbc")
		self.assertEquals(("z"):capitalize(), "Z")
		-- UTF-8
		self.assertEquals(("привет"):capitalize(), "Привет")
	end;
	testBeginsWith = function (self)
		self.assertTrue(("abcdefgh"):beginsWith"abcde")
		self.assertFalse(("abcdefgh"):beginsWith"abcdf")
		-- UTF-8
		self.assertTrue(("привет!"):beginsWith"приве")
		self.assertFalse(("Привет!"):beginsWith"Превед")
	end;
	testEndsWith = function (self)
		self.assertTrue(("abcdefgh"):endsWith"efgh")
		self.assertFalse(("abcdefgh"):endsWith"efg")
		-- UTF-8
		self.assertTrue(("привет!"):endsWith"ивет!")
		self.assertFalse(("привет!"):endsWith"ивет")
	end;
	testFindLast = function (self)
		self.assertEquals(("Hello, Hell!"):findLast"ell", 9)
		self.assertNil(("Hello, Hell!"):findLast"ellz")
		-- UTF-8 unsupported
		-- self.assertEquals(("Превед, Медвед!"):findLast"вед", 12)
	end;
	testLower = function (self)
		self.assertEquals(("abcdef"):lower(), "abcdef")
		self.assertEquals(("ABCDEF"):lower(), "abcdef")
		-- UTF-8
		self.assertEquals(("ПРЕВЕД!"):lower(), "превед!")
	end;
	testUpper = function (self)
		self.assertEquals(("abcdef"):upper(), "ABCDEF")
		self.assertEquals(("ABCDEF"):upper(), "ABCDEF")
		-- UTF-8
		self.assertEquals(("превед!"):upper(), "ПРЕВЕД!")
	end;
	testTrim = function (self)
		self.assertEquals(([[
		abcdf ghb		
		
		
		]]):trim(), "abcdf ghb")
		-- UTF-8
		self.assertEquals(([[
			     Превед, Мир!
				 
				   ]]):trim(), "Превед, Мир!")
	end;
	testSerialize = function (self)
		self.assertEquals(string.serialize{"a\"bc";10;false;nil;function() end}, [[{"a\"bc";10;false}]])
		local a = string.unserialize[[{"a\"bc";10;false}]]
		self.assertEquals(a[1], "a\"bc")
		self.assertEquals(a[2], 10)
		self.assertEquals(a[3], false)
		self.assertEquals(string.serialize{"пре\"вед";50;"мир"}, [[{"пре\"вед";50;"мир"}]])
		local a = string.unserialize[[{"пре\"вед";50;"мир"}]]
		self.assertEquals(a[1], "пре\"вед")
		self.assertEquals(a[2], 50)
		self.assertEquals(a[3], "мир")
	end;
}
