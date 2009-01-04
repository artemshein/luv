local TestCase, User, UserGroup = require"TestCase", require"Models.User", require"Models.UserGroup"

module(...)

return TestCase:extend{
	__tag = "Tests.Models.User",

	testSimple = function (self)
		local u = User:new()
		self.assertTrue(u:getField"group":getRefModel():isKindOf(UserGroup))
		local g = UserGroup:new()
		self.assertThrows(function () u.group = 15 end)
		self.assertThrows(function () u.group = "abcd" end)
		self.assertThrows(function () u.group = u end)
		self.assertNotThrows(function () u.group = g end)
	end
}
