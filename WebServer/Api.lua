local Object, Exception = require"ProtOo", require"Exception"

module(...)

return Object:extend{
	__tag = "WebServer.Api",

	Exception = Exception:extend{__tag = "WsApi.Exception"},

	getRequestHeader = Object.abstractMethod,
	getResponseHeader = Object.abstractMethod,
	setResponseHeader = Object.abstractMethod
}
