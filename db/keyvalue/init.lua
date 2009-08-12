local require = require
local Object = require"luv.oop".Object
local Exception = require"luv.exceptions".Exception
local string = require"luv.string"

module(...)
local MODULE = (...)
local abstract = Object.abstractMethod

local Factory = Object:extend{
	__tag = .....".Factory";
	new = function (self, dsn)
		local login, pass, port, params = nil, nil, nil, {}
		local driver, host, database, paramsStr = dsn:split("://", "/", "?")
		login, host = host:split"@"
		if not host then
			host = login
			login = nil
		end
		if not host then
			host = "localhost"
		end
		if login then login, pass = login:split":" end
		host, port = host:split":"
		if paramsStr then paramsStr = paramsStr:split"&" end
		if paramsStr then
			for _, v in ipairs(paramsStr) do
				local key, val = v:split"="
				params[key] = val
			end
		end
		return require(MODULE.."."..driver).Driver(host, login, pass, database, port, params)
	end;
}

local Driver = Object:extend{
	__tag = .....".Driver",
	Exception = Exception:extend{__tag = .....".Driver.Exception"};
	_logger = function () end;
	logger = Object.property;
	get = abstract;
	set = abstract;
	del = abstract;
	incr = abstract;
	decr = abstract;
	exists = absrtract;
	flush = abstract;
	close = abstract;
	error = function (self) return self._error end;
}

return {Factory=Factory;Driver=Driver;}
