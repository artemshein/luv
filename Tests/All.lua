local TestCase = require"TestCase"

module(...)

local AllTests = TestCase:extend{
	tests = {
		"Tests.Self", "Tests.Version", "Tests.Templaters.Tamplier",
		"Tests.Validators.Filled", "Tests.Validators.Length", "Tests.Validators.Value", "Tests.Validators.Int",
		"Tests.Fields.Field", "Tests.Fields.Char"
	}
}

return AllTests