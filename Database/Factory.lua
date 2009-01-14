local Object, Exception, String = require"ProtOo", require"Exception", require"String"
local require, ipairs, Debug = require, ipairs, require"Debug"

module(...)

return Object:extend{
	__tag = "Database.Factory",
	Exception = Exception:extend{},
	
	connect = function (self, dsn)
		local login, pass, port, params = nil, nil, nil, {}
		local driver, host, database, paramsStr = String.split(dsn, "://", "/", "?")
		login, host = String.split(host, "@")
		login, pass = String.split(login, ":")
		host, port = String.split(host, ":")
		paramsStr = String.split(paramsStr, "&")
		if paramsStr then
			for _, v in ipairs(paramsStr) do
				local key, val = String.split(v, "=")
				params[key] = val
			end
		end
		return require("Database."..String.capitalize(driver))(host, login, pass, database, port, params)
	end
}
