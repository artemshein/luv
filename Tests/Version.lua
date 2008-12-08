local UnitTest, Version = require"UnitTest", require"Version"

module(...)

local Version = UnitTest:extend{
	testSimple = function (self)
		local ver = Version:new(1, 2, 12, "dev", 334, "Eagle")
		assertEquals(ver:full(), "1.2.12dev rev334 Eagle")
		ver = Version:new(0, 5)
		assertEquals(ver:full(), "0.5")
	end
}

return Version