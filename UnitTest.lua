local pairs, io, require, os, type = pairs, io, require, os, type
local Object, Exception, Namespace, TestCase = from"Luv":import("Object", "Exception", "Namespace", "TestCase")

module(...)

return Object:extend{
	__tag = ...,
	
	run = function (self)
		local testModule
		if not self.tests then
			Exception"No tests are defined!":throw()
		end
		local total, failed, time = 0, 0, os.clock()
		local runTest = function (test)
			local res = test:run()
			if not res then
				failed = failed+1
			end
			total = total+1
			io.write"\n\n"
		end
		for _, test in pairs(self.tests) do
			io.write(test, ": ")
			testModule = require(test)
			if testModule:isKindOf(Namespace) then
				local t
				for _, t in pairs(testModule) do
					if "table" == type(t) and t.isKindOf and t:isKindOf(TestCase) then
						runTest(t)
					end
				end
			else
				runTest(testModule)
			end
		end
		io.write"==\n"
		if 0 == failed then
			io.write("PASS ", total, " unit tests in ", os.clock()-time, " sec")
		else
			io.write("FAIL ", failed, "/", total, " unit tests in ", os.clock()-time, " sec")
		end
	end
}
