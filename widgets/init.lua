local Object, Namespace = from"Luv":import("Object", "Namespace")

module(...)

local Widget = Object:extend{
	__tag = .....".Widget",
	render = Object.abstractMethod
}

return Namespace:extend{
	__tag = ...,
	Widget = Widget
}
