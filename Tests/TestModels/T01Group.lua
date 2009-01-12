local Model, Int, OneToMany = require"Models.Model", require"Fields.Int", require"Fields.OneToMany"

module(...)

return Model:extend{
	__tag = "Tests.TestModels.T01Group",

	number = Int:new{pk = true},
	students = OneToMany:new"Tests.TestModels.T01Student"
}
