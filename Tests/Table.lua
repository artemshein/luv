local TestCase, Table = require"Luv.TestCase", require"Luv.Table"

module(...)

return TestCase:extend{
	__tag = ...,

	testSplit = function (self)
		self.assertEquals(Table.join({"abc", "def", "", "234", "false"}), "abcdef234false")
		self.assertEquals(Table.join({"abc", "def", "", "234", "false"}, "||"), "abc||def||||234||false")
		self.assertEquals(Table.join({}, "+"), "")
	end
}
