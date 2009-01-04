local UnitTest = require"UnitTest"

module(...)

local AllTest = UnitTest:extend{
	tests = {
		-- Base functional
		"Tests.Self", "Tests.String", "Tests.Table", "Tests.CheckTypes", "Tests.ProtOo", "Tests.Version",
		-- Template engines
		"Tests.Templaters.Tamplier",
		-- Database
		"Tests.Database.Factory", "Tests.Database.Driver", "Tests.Database.Mysql",
		-- Validators
		"Tests.Validators.Filled", "Tests.Validators.Length", "Tests.Validators.Value", "Tests.Validators.Int", "Tests.Validators.Regexp",
		-- Fields
		"Tests.Fields.Field", "Tests.Fields.Char", "Tests.Fields.Login", "Tests.Fields.ManyToOne",
		-- Widgets
		"Tests.Widgets.InputField",
		-- QuerySet
		"Tests.QuerySet",
		-- Models
		"Tests.Models.Model", "Tests.Models.User", "Tests.Models.UserGroup", "Tests.Models.GroupRight"
	}
}

return AllTest
