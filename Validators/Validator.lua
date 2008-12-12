local Object = require"ProtOo"

module(...)

local Validator = Object:extend{
	validate = Object.abstractMethod,
}

return Validator