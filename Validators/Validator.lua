local Object = require"ProtOo"

module(...)

local Validator = Object:extend{
	__tag = "Validators.Validator",
	
	validate = Object.abstractMethod,
}

return Validator