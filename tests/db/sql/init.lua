local TestCase, sql = require "luv.dev.unittest".TestCase, require "luv.db.sql"

module(...)

local validDsn = "mysql://test:test@localhost/test" -- This DSN should be valid!

local Factory = TestCase:extend{
	__tag = .....".Factory",
	invalidDsn = "mysql://invalid-user:invalid-pass@invalid-host/invalid-db", -- This DSN should be invalid!
	validDsn = validDsn,
	testConnect = function (self)
		self.assertThrows(function () db.Factory(self.invalidDsn) end)
		local v = sql.Factory(self.validDsn)
		self.assertTrue(v:isA(sql.Driver))
	end
}

local Driver = TestCase:extend{
	__tag = .....".Driver",
	dsn = validDsn,
	testQueries = function (self)
		local v = sql.Factory(self.dsn)
		v:query("DROP TABLE ?#", "test")
		v:query("CREATE TABLE ?# (?# INTEGER PRIMARY KEY, ?# VARCHAR(255))", "test", "num", "title")
		self.assertEquals(v:query("INSERT INTO ?# SET ?v", "test", {num=10, title="abc"}), 1)
		self.assertEquals(v:query("INSERT INTO ?# (?#) VALUES (?d, ?), (?d, ?)", "test", {"num", "title"}, 20, "", 30, "def"), 2)
		local res = v:fetchAll("SELECT * FROM ?#", "test")
		self.assertEquals(#res, 3)
		self.assertEquals(res[1].num, "10")
		self.assertEquals(res[1].title, "abc")
		self.assertEquals(res[2].num, "20")
		self.assertEquals(res[2].title, "")
		self.assertEquals(res[3].num, "30")
		self.assertEquals(res[3].title, "def")
		res = v:fetchRow("SELECT * FROM ?# WHERE ?#=?d", "test", "num", 30)
		self.assertEquals(res.num, "30")
		self.assertEquals(res.title, "def")
		self.assertEquals(v:fetchCell("SELECT ?# FROM ?# WHERE ?#=?d", "title", "test", "num", 10), "abc")
		v:query("DROP TABLE ?#", "test")
	end
}

return {
	Factory = Factory,
	Driver = Driver
}
