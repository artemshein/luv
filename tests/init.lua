local TestSuite = require "luv.dev.unittest".TestSuite

module(...)

local all = TestSuite{
	-- Base functional
	"luv.tests.self";"luv.tests.string";"luv.tests.table";"luv.tests.checktypes";"luv.tests.oop";"luv.tests.utils";
	-- Crypt
	"luv.tests.crypt";
	-- Template engines
	"luv.tests.templaters.tamplier";
	-- Database
	"luv.tests.db.sql"; "luv.tests.db.sql.mysql"; "luv.tests.db.keyvalue.redis";
	-- Validators
	"luv.tests.validators";
	-- Fields
	"luv.tests.fields";
	-- Widgets ()
	--"Tests.Widgets.InputField",
	-- QuerySet
	--"luv.tests.querySet",
	-- Models
	"luv.tests.db.models";
	-- Forms
	"luv.tests.forms";
	-- Cache
	"luv.tests.cache";
}

return {all=all}
