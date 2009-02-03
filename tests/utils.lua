local TestCase, Version = require"luv.unittest".TestCase, require"luv.utils".Version

module(...)

return TestCase:extend{
	__tag = ...,
	testSimple = function (self)
		local ver = Version(1, 2, 12, "dev", 334, "Eagle")
		self.assertEquals(ver:full(), "1.2.12dev rev334 Eagle")
		ver = Version(0, 5)
		self.assertEquals(ver:full(), "0.5")
	end
}
