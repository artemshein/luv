local tostring = tostring
local TestCase, Crypt, String = require"Luv.TestCase", require"Luv.Crypt", require"Luv.String"

module(...)

return TestCase:extend{
	__tag = ...,

	testMd5 = function (self)
		local hash = tostring(Crypt.Md5"test message")
		self.assertEquals(String.len(hash), 32)
		self.assertEquals(hash, "c72b9698fa1927e1dd12d3cf26ed84b2")
		self.assertEquals(hash, tostring(Crypt.Md5"test message"))
	end,
	testSha1 = function (self)
		local hash = tostring(Crypt.Sha1"test message")
		self.assertEquals(String.len(hash), 40)
		self.assertEquals(hash, "35ee8386410d41d14b3f779fc95f4695f4851682")
		self.assertEquals(hash, tostring(Crypt.Sha1"test message"))
	end
}
