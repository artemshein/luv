local loadstring, assert = loadstring, assert
local checkTypes = require"luv.checktypes".checkTypes

module(...)

local cachedFuncs = {}

local f = checkTypes("string", function (code)
	local func = cachedFuncs[code]
	if not func then
		func = assert(loadstring("return function (a,b,c,d,e,f) return "..code.." end"))()
		cachedFuncs[code] = func
	end
	return func
end, "function")

return {f=f}
