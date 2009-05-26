local loadstring, assert = loadstring, assert

module(...)

local f = function (code)
	code = 'return function (a,b,c,d,e,f) return '..code..' end'
	return assert(loadstring(code))()
end

return {f=f}
