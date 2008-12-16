local TestCase = require"TestCase"

module(...)

local AllTests = TestCase:extend{
	tests = {
		"Tests.Self", "Tests.String", "Tests.CheckTypes", "Tests.ProtOo", "Tests.Version", "Tests.Templaters.Tamplier",
		
		"Tests.Database.Factory",
		
		"Tests.Validators.Filled", "Tests.Validators.Length", "Tests.Validators.Value", "Tests.Validators.Int",
		"Tests.Fields.Field", "Tests.Fields.Char",
		"Tests.Models.Model"
	}
}

return AllTests