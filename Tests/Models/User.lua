local io, tostring = io, tostring
local TestCase, User, UserGroup, Factory = require"TestCase", require"Models.User", require"Models.UserGroup", require"Database.Factory"

module(...)

return TestCase:extend{
	__tag = "Tests.Models.User",

	validDsn = "mysql://test:test@localhost/test",

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
