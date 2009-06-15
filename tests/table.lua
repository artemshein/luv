local table = require"luv.table"
local TestCase = require "luv.dev.unittest".TestCase

module(...)

return TestCase:extend{
	__tag = ...,
	testSplit = function (self)
		self.assertEquals(table.join({"abc", "def", "", "234", "false"}), "abcdef234false")
		self.assertEquals(table.join({"abc", "def", "", "234", "false"}, "||"), "abc||def||||234||false")
		self.assertEquals(table.join({}, "+"), "")
	end
}
