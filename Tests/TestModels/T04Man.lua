local Model, Char, ManyToMany = require"Models.Model", require"Fields.Char", require"Fields.ManyToMany"

module(...)

return Model:extend{
	__tag = "Tests.TestModels.T01Man",

	fields = {
		name = Char:new{primaryKey = true},
		friends = ManyToMany:new"Tests.TestModels.T01Man"
	}
}
