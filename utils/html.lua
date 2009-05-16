local string = require"luv.string"
local type, tostring = type, tostring

module(...)

local escape = function (str)
	if "string" ~= type(str) then str = tostring(str) end
	local repl = {["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;"}
	return (string.gsub(str, "[<>\"]", repl))
end

return {
	escape = escape
}
