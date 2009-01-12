local TestCase, GroupRight, UserGroup = require"TestCase", require"Models.GroupRight", require"Models.UserGroup"

module(...)

return TestCase:extend{
	__tag = "Tests.Models.GroupRight",

	testSimple = function (self)
		local g = GroupRight:new()
		self.assertTrue(g:getField"groups":getRefModel():isKindOf(UserGroup))
		--local u = UserGroup:new()
		--self.assertThrows(function () g.end)
	end
}
