require"luv.string"
local string, type = string, type

module(...)

local escape = function (str)
	if "string" ~= type(str) then str = tostring(str) end
	local repl = {["<"] = "&lt;", [">"] = "&gt;", ["\""] = "&quot;"}
	return (string.gsub(str, "[<>\"]", repl))
end

return {
	escape = escape
}
