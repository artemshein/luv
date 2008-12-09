local Object = require"ProtOo"

module(...)

local Widget = Object:extend{
	render = abstractMethod
}

return Widget