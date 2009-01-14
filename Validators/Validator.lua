local Object = require"ProtOo"

module(...)

return Object:extend{
	__tag = "Validators.Validator",
	
	validate = Object.abstractMethod
}
