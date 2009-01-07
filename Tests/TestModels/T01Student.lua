local Model, Char, ManyToOne = require"Models.Model", require"Fields.Char", require"Fields.ManyToOne"

module(...)

return Model:extend{
	__tag = "Tests.TestModels.T01Student",

	name = Char:new{pk = true},
	group = ManyToOne:new{references="Tests.TestModels.T01Group", required=true}
}
