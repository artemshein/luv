local io, tostring = io, tostring
local TestCase, db, mysql = require "luv.dev.unittest".TestCase, require "luv.db", require "luv.db.mysql"

module(...)

local validDsn = "mysql://test:test@localhost/test"

return TestCase:extend{
	__tag = ...,
	dsn = validDsn,
	setUp = function (self)
		self.db = db.Factory(self.dsn)
		self.db:setLogger(function (sql, result)
			io.write(sql, "<br />")
		end)
	end,
	testPlaceholders = function (self)
		local db = self.db
		self.assertEquals(db:processPlaceholder("?#", "test"), "`test`")
		self.assertEquals(db:processPlaceholder("?#", "te`st"), "`te``st`")
		self.assertEquals(db:processPlaceholder("?d", 55), "55")
		self.assertThrows(function() db:processPlaceholder("?d", "NaN") end)
		self.assertEquals(db:processPlaceholder("?", "test"), [['test']])
		self.assertEquals(db:processPlaceholder("?", "te\"s't"), [['te"s\'t']])
	end,
	testPlaceholders = function (self)
		local db = self.db
		self.assertEquals(db:processPlaceholders(
			"SELECT ?#, ?# FROM ?# WHERE ?# > ?d AND ?# < ?d OR ?# = ?", "id", "title_and_name", "testTable", "id", -46, "id", 58, "test`field``", "test string\" \'there\'"),
			"SELECT `id`, `title_and_name` FROM `testTable` WHERE `id` > -46 AND `id` < 58 OR `test``field````` = 'test string\" \\'there\\''"
		)
		self.assertEquals(db:processPlaceholders(
			"SELECT ?# FROM ?# WHERE ?# IN (?a)", "name", "test", "id", {23, 45, 56, 72, 84}),
			"SELECT `name` FROM `test` WHERE `id` IN (23, 45, 56, 72, 84)"
		)
		self.assertEquals(db:processPlaceholders(
			"INSERT INTO ?# SET ?v", "test", {name="Max", age=23, gender="M"}),
			"INSERT INTO `test` SET `gender`='M', `name`='Max', `age`=23"
		)
	end,
	testSelects = function (self)
		self.assertEquals(
			tostring(self.db:Select("id", "title"):from("test.table"):where("?# = ?d", "num", 55):orWhere("?# = ?n", "parent"):limitPage(3, 10):order("num", "-date", "*")),
			"SELECT `id`, `title` FROM `test`.`table` WHERE (`num` = 55) OR (`parent` = NULL) ORDER BY `num` ASC, `date` DESC, RAND() LIMIT 10 OFFSET 20;"
		)
		self.assertEquals(
			tostring(self.db:SelectRow({p = "test.fld", f = "test.fld2", c = "COUNT(test.counter)"}):from({test = "dtb.test_table", p = "dtb.products"}):order("MAX(test.counter)")),
			"SELECT `test`.`fld` AS `p`, COUNT(test.counter) AS `c`, `test`.`fld2` AS `f` FROM `dtb`.`test_table` AS `test`, `dtb`.`products` AS `p` ORDER BY MAX(test.counter) ASC;"
		)
		self.assertEquals(
			tostring(self.db:SelectCell():from("tabl`e"):where("?# = 0 OR ?# IS NULL AND (MAX(?#) < 150)", "id", "id", "total"):limit(10, 25)),
			"SELECT `tabl``e`.* FROM `tabl``e` WHERE (`id` = 0 OR `id` IS NULL AND (MAX(`total`) < 150)) LIMIT 15 OFFSET 10;"
		)
		-- Test limit
		self.assertEquals(
			tostring(self.db:Select():from("test"):limit(5)),
			"SELECT `test`.* FROM `test` LIMIT 5;"
		)
	end,
	testInsertRow = function (self)
		self.assertEquals(
			tostring(self.db:InsertRow():into("test"):set("?# = ?d, ?# = ?n", "num", 55, "title"):set("?# = ?", "desc", "Description")),
			"INSERT INTO `test` SET `num` = 55, `title` = NULL, `desc` = 'Description';"
		)
	end,
	testInsert = function (self)
		self.assertEquals(
			tostring(self.db:Insert("?, ?n, ?d", "title", "parent", "total"):into("test"):values("abc", nil, 32):values("cde", 15, 64):values("efg", "", -74)),
			"INSERT INTO `test` (`title`, `parent`, `total`) VALUES ('abc', NULL, 32), ('cde', 15, 64), ('efg', NULL, -74);"
		)
	end,
	testUpdate = function (self)
		self.assertEquals(
			tostring(self.db:Update("test"):set("?# = ?", "title", "abc"):set("?# = RAND()", "rand"):set("?# = ?n", "parent"):where("?# = ?d", "num", 55):order("num"):limit(10)),
			"UPDATE `test` SET `title` = 'abc', `rand` = RAND(), `parent` = NULL WHERE (`num` = 55) ORDER BY `num` ASC LIMIT 10;"
		)
	end,
	testUpdateRow = function (self)
		self.assertThrows(function () self.db:UpdateRow("test"):limitPage(1, 20) end)
		self.assertEquals(
			tostring(self.db:UpdateRow("test"):set("?# = ?", "title", "abc"):set("?# = RAND()", "rand"):set("?# = ?n", "parent"):where("?# = ?d", "num", 55):order("num"):limit(10)),
			"UPDATE `test` SET `title` = 'abc', `rand` = RAND(), `parent` = NULL WHERE (`num` = 55) ORDER BY `num` ASC LIMIT 1;"
		)
	end,
	testDelete = function (self)
		self.assertEquals(
			tostring(self.db:Delete():from("test"):where("?# = CONCAT(?, ?)", "name", "John ", "Smith"):limit(5, 10)),
			"DELETE FROM `test` WHERE (`name` = CONCAT('John ', 'Smith')) LIMIT 5 OFFSET 5;"
		)
	end,
	testDeleteRow = function (self)
		self.assertEquals(
			tostring(self.db:DeleteRow():from("test"):order("-date", "*"):limit(15, 20)),
			"DELETE FROM `test` ORDER BY `date` DESC, RAND() LIMIT 1 OFFSET 15;"
		)
	end,
	testCreateTable = function (self)
		self.assertEquals(
			tostring(self.db:CreateTable("test_`tbl"):field("id", "INTEGER", {primaryKey = true, serial = true}):field("title", "VARCHAR(255)", {null = true, unique = true, default = "NULL"}):option("charset", "latin1"):option("engine", "MyISAM")),
			"CREATE TABLE `test_``tbl` (`id` INTEGER PRIMARY KEY AUTO_INCREMENT NOT NULL, `title` VARCHAR(255) NULL UNIQUE DEFAULT NULL) CHARACTER SET latin1 ENGINE = MyISAM;"
		)
		self.assertEquals(
			tostring(self.db:CreateTable("test"):field("lang", "CHAR(2)", {unique = true}):field("url", "TEXT"):uniqueTogether("lang", "url"):constraint("lang", "dtb.langs", "id", "SET NULL", "SET NULL")),
			"CREATE TABLE `test` (`lang` CHAR(2) NOT NULL UNIQUE, `url` TEXT NOT NULL, UNIQUE (`lang`, `url`), CONSTRAINT FOREIGN KEY (`lang`) REFERENCES `dtb`.`langs` (`id`) ON UPDATE SET NULL ON DELETE SET NULL) CHARACTER SET utf8 ENGINE = InnoDB;"
		)
	end,
	testDropTable = function (self)
		self.assertEquals(
			tostring(self.db:DropTable("data.tbl")),
			"DROP TABLE `data`.`tbl`;"
		)
	end,
	testJoins = function (self)
		self.assertEquals(
			tostring(self.db:Select("p.product_id", "p.product_name"):from{p="products"}:join({l="line_items"}, {"?# = ?#", "p.product_id", "l.product_id"})),
			"SELECT `p`.`product_id`, `p`.`product_name` FROM `products` AS `p` JOIN `line_items` AS `l` ON `p`.`product_id` = `l`.`product_id`;"
		)
	end
}
