local TestCase, Factory, Driver = require"TestCase", require"Database.Factory", require"Database.Driver"
local Debug, io, tostring = require"Debug", io, tostring

module(...)

local DriverTest = TestCase:extend{
	dsn = "mysql://test:test@localhost/test",
	testQueries = function (self)
		local db = Factory:connect(self.dsn)
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
	end,
	testClasses = function (self)
		local db = Factory:connect(self.dsn)
		self.assertTrue(db:isKindOf(Driver))
		self.assertTrue(db:select("test"):isKindOf(db.Select))
		self.assertTrue(db:selectRow("test"):isKindOf(db.SelectRow))
		self.assertTrue(db:selectCell("test"):isKindOf(db.SelectCell))
		self.assertTrue(db:update("test"):isKindOf(db.Update))
		self.assertTrue(db:insert("test"):isKindOf(db.Insert))
		self.assertTrue(db:insertRow("test"):isKindOf(db.InsertRow))
		self.assertTrue(db:delete("test"):isKindOf(db.Delete))
		self.assertTrue(db:dropTable("test"):isKindOf(db.DropTable))
		self.assertTrue(db:createTable("test"):isKindOf(db.CreateTable))
	end
}

return DriverTest