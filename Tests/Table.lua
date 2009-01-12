local TestCase, Table = require"TestCase", require"Table"

module(...)

local TableTest = TestCase:extend{
	testSplit = function (self)
		self.assertEquals(Table.join({"abc", "def", "", "234", "false"}), "abcdef234false")
		self.assertEquals(Table.join({"abc", "def", "", "234", "false"}, "||"), "abc||def||||234||false")
		self.assertEquals(Table.join({}, "+"), "")
	end
}

return TableTest