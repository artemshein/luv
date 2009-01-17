local Object, Namespace, Exception = from"Luv":import("Object", "Namespace", "Exception")

module(...)

local Exception = Exception:extend{__tag = .....".Exception"}

local Api = Object:extend{
	__tag = .....".Api",

	getRequestHeader = Object.abstractMethod,
	getResponseHeader = Object.abstractMethod,
	setResponseHeader = Object.abstractMethod
}

return Namespace:extend{
	__tag = ...,

	ns = ...,
	Exception = Exception,
	Api = Api
}
