local Object = require"ProtOo"

module(...)

local Validator = Object:extend{
	validate = abstractMethod,
}

return Validator