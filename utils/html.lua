require"luv.string"
local string = string

module(...)

local escape = function (str)
	local repl = {["<"] = "&lt;", [">"] = "&gt;"}
	return (string.gsub(str, "[<>]", repl))
end

return {
	escape = escape
}
