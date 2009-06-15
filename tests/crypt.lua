local string = require "luv.string"
local tostring = tostring
local TestCase, crypt = require "luv.dev.unittest".TestCase, require "luv.crypt"

module(...)

return TestCase:extend{
	__tag = ...,
	testMd5 = function (self)
		local hash = tostring(crypt.Md5"test message")
		self.assertEquals(string.len(hash), 32)
		self.assertEquals(hash, "c72b9698fa1927e1dd12d3cf26ed84b2")
		self.assertEquals(hash, tostring(crypt.Md5"test message"))
	end,
	testSha1 = function (self)
		local hash = tostring(crypt.Sha1"test message")
		self.assertEquals(string.len(hash), 40)
		self.assertEquals(hash, "35ee8386410d41d14b3f779fc95f4695f4851682")
		self.assertEquals(hash, tostring(crypt.Sha1"test message"))
	end
}
