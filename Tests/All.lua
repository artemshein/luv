local UnitTest = require"Luv.UnitTest"

module(...)

return UnitTest:extend{
	__tag = ...,

	tests = {
		-- Base functional
		"Luv.Tests.Self", "Luv.Tests.String", "Luv.Tests.Table", "Luv.Tests.CheckTypes", "Luv.Tests.Object", "Luv.Tests.Version",
		-- Crypt
		"Luv.Tests.Crypt",
		-- Template engines
		"Luv.Tests.Templater.Tamplier",
		-- Database
		"Luv.Tests.Db", "Luv.Tests.Db.Mysql",
		-- Validators
		"Luv.Tests.Validators",
		-- Fields
		"Luv.Tests.Fields",
		-- Widgets ()
		--"Tests.Widgets.InputField",
		-- QuerySet
		"Luv.Tests.QuerySet",
		-- Models
		"Luv.Tests.Model"
	}
}
