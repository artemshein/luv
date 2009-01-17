local Namespace, TestCase, Db = from"Luv":import("Namespace", "TestCase", "Db")

module(...)

local validDsn = "mysql://test:test@localhost/test" -- This DSN should be valid!

local Factory = TestCase:extend{
	invalidDsn = "mysql://invalid-user:invalid-pass@invalid-host/invalid-db", -- This DSN should be invalid!
	validDsn = validDsn,
	testConnect = function (self)
		self.assertThrows(function () Db.Factory:connect(self.invalidDsn) end)
		local db = Db.Factory:connect(self.validDsn)
		self.assertTrue(db:isKindOf(Db.Driver))
	end
}

local Driver = TestCase:extend{
	dsn = validDsn,
	testQueries = function (self)
		local db = Db.Factory:connect(self.dsn)
		db:query("DROP TABLE ?#", "test")
		db:query("CREATE TABLE ?# (?# INTEGER PRIMARY KEY, ?# VARCHAR(255))", "test", "num", "title")
		self.assertEquals(db:query("INSERT INTO ?# SET ?v", "test", {num=10, title="abc"}), 1)
		self.assertEquals(db:query("INSERT INTO ?# (?#) VALUES (?d, ?), (?d, ?)", "test", {"num", "title"}, 20, "", 30, "def"), 2)
		local res = db:fetchAll("SELECT * FROM ?#", "test")
		self.assertEquals(#res, 3)
		self.assertEquals(res[1].num, "10")
		self.assertEquals(res[1].title, "abc")
		self.assertEquals(res[2].num, "20")
		self.assertEquals(res[2].title, "")
		self.assertEquals(res[3].num, "30")
		self.assertEquals(res[3].title, "def")
		res = db:fetchRow("SELECT * FROM ?# WHERE ?#=?d", "test", "num", 30)
		self.assertEquals(res.num, "30")
		self.assertEquals(res.title, "def")
		self.assertEquals(db:fetchCell("SELECT ?# FROM ?# WHERE ?#=?d", "title", "test", "num", 10), "abc")
		db:query("DROP TABLE ?#", "test")
	end
}

return Namespace:extend{
	__tag = ...,

	ns = ...,
	validDsn = validDsn,
	Factory = Factory,
	Driver = Driver
}
