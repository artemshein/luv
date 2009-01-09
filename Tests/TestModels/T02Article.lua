local Model, Char, ManyToMany = require"Models.Model", require"Fields.Char", require"Fields.ManyToMany"

module(...)

return Model:extend{
	__tag = "Tests.TestModels.T02Article",

	title = Char:new{required=true},
	categories = ManyToMany:new{references="Tests.TestModels.T02Category", required=true}
}
