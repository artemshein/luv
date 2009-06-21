local string = require "luv.string"
local dev = require "luv.dev"
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
		-- UTF-8
		self.assertEquals(string.slice("Привет, Мир!", 9), "Мир!")
		self.assertEquals(string.slice("Привет, Мир!", 9, -2), "Мир")
		self.assertEquals(string.slice("Привет, Мир!", 1, 6), "Привет")
	end;
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
		-- UTF-8
		local a, b, c = string.split("Привет, Мир!", "и", "Ми")
		self.assertEquals(a, "Пр")
		self.assertEquals(b, "вет, ")
		self.assertEquals(c, "р!")
	end;
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
		-- UTF-8
		local a = string.explode("Привет, и Мир! и Пыщь!!!11", " и ")
		self.assertEquals(a[1], "Привет,")
		self.assertEquals(a[2], "Мир!")
		self.assertEquals(a[3], "Пыщь!!!11")
		self.assertNil(a[4])
	end;
	testCapitalize = function (self)
		self.assertEquals(string.capitalize("abc"), "Abc")
		self.assertEquals(string.capitalize("1bc"), "1bc")
		self.assertEquals(string.capitalize("Gbc"), "Gbc")
		self.assertEquals(string.capitalize("z"), "Z")
		-- UTF-8
		self.assertEquals(string.capitalize("привет"), "Привет")
	end;
	testBeginsWith = function (self)
		self.assertTrue(string.beginsWith("abcdefgh", "abcde"))
		self.assertFalse(string.beginsWith("abcdefgh", "abcdf"))
		-- UTF-8
		self.assertTrue(string.beginsWith("привет!", "приве"))
		self.assertFalse(string.beginsWith("Привет!", "Превед"))
	end;
	testEndsWith = function (self)
		self.assertTrue(string.endsWith("abcdefgh", "efgh"))
		self.assertFalse(string.endsWith("abcdefgh", "efg"))
		-- UTF-8
		self.assertTrue(string.endsWith("привет!", "ивет!"))
		self.assertFalse(string.endsWith("привет!", "ивет"))
	end;
	testFindLast = function (self)
		self.assertEquals(string.findLast("Hello, Hell!", "ell"), 9)
		self.assertNil(string.findLast("Hello, Hell!", "ellz"))
		-- UTF-8 unsupported
		-- self.assertEquals(string.findLast("Превед, Медвед!", "вед"), 12)
	end;
	testTrim = function (self)
		self.assertEquals(string.trim([[ 	
		abcdf ghb		
		
		
		]]), "abcdf ghb")
		-- UTF-8
		self.assertEquals(string.trim([[
			     Превед, Мир!
				 
				   ]]), "Превед, Мир!")
	end;
	testSerialize = function (self)
		self.assertEquals(string.serialize{"a\"bc";10;false;nil;function() end}, [[{[1]="a\"bc";[2]=10;[3]=false}]])
		local a = string.unserialize[[{[1]="a\"bc";[2]=10;[3]=false}]]
		self.assertEquals(a[1], "a\"bc")
		self.assertEquals(a[2], 10)
		self.assertEquals(a[3], false)
		self.assertEquals(string.serialize{"пре\"вед";50;"мир"}, [[{[1]="пре\"вед";[2]=50;[3]="мир"}]])
		local a = string.unserialize[[{[1]="пре\"вед";[2]=50;[3]="мир"}]]
		self.assertEquals(a[1], "пре\"вед")
		self.assertEquals(a[2], 50)
		self.assertEquals(a[3], "мир")
	end;
}
