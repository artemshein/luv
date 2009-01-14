local tostring = tostring
local TestCase, Md5, String = require"TestCase", require"Crypt.Md5", require"String"

module(...)

return TestCase:extend{
	__tag = "Tests.Crypt.Md5",

	testSimple = function (self)
		local hash = tostring(Md5:new"test message")
		self.assertEquals(String.len(hash), 32)
		self.assertEquals(hash, "c72b9698fa1927e1dd12d3cf26ed84b2")
		self.assertEquals(hash, tostring(Md5:new"test message"))
	end
}
