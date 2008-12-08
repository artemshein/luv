local TestCase = require"TestCase"

module(...)

local AllTests = TestCase:extend{
	tests = {"Tests.Self", "Tests.Version", "Tests.Templaters.Tamplier", "Tests.Fields.Field"}
}

return AllTests