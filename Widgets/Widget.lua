local Object = require"ProtOo"

module(...)

local Widget = Object:extend{
	__tag = "Widgets.Widget",
	
	render = Object.abstractMethod
}

return Widget