local Object, Exception = require"ProtOo", require"Exception"
local pairs, io, require, os = pairs, io, require, os

module(...)

local UnitTest = Object:extend{
	tests = nil,
	
	run = function (self)
		local testModule
		if not self.tests then
			Exception:new"No tests are defined!":throw()
		end
		local res, total, failed, time = nil, 0, 0, os.clock()
		for _, test in pairs(self.tests) do
			io.write(test, ": ")
			testModule = require(test)
			res = testModule:run()
			if not res then
				failed = failed+1
			end
			total = total+1
			io.write"\n\n"
		end
		io.write"==\n"
		if 0 == failed then
			io.write("PASS ", total, " unit tests in ", os.clock()-time, " sec")
		else
			io.write("FAIL ", failed, "/", total, " unit tests in ", os.clock()-time, " sec")
		end
	end
}

return UnitTest