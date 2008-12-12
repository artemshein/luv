local Object, Exception, Cgi
local res, exc = pcall(function ()
	Object, Exception, Cgi = require"ProtOo", require"Exception", require"Cgi"
end)

if not res then
	io.write"Content-type: text/html\n\n"
	io.write(exc)
end

local Luv

try(function()
	Luv = Object:extend{}
end):catch(function (e)
	io.write(e)
end)

return Luv
