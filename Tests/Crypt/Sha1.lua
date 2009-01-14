local tostring = tostring
local TestCase, Sha1, String = require"TestCase", require"Crypt.Sha1", require"String"

module(...)

return TestCase:extend{
	__tag = "Tests.Crypt.Sha1",

	testSimple = function (self)
		local hash = tostring(Sha1:new"test message")
		self.assertEquals(String.len(hash), 40)
		self.assertEquals(hash, "35ee8386410d41d14b3f779fc95f4695f4851682")
		self.assertEquals(hash, tostring(Sha1:new"test message"))
	end
}
