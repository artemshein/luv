local TestCase, UserGroup, GroupRight = require"TestCase", require"Models.UserGroup", require"Models.GroupRight"

module(...)

return TestCase:extend{
	__tag = "Tests.Models.UserGroup",

	testSimple = function (self)
		local g = UserGroup()
		self.assertTrue(g:getField"rights":getRefModel():isKindOf(GroupRight))
	end
}
