require"luv.string"
require"luv.table"
local pairs, io, require, os, type, unpack, string, table, tostring = pairs, io, require, os, type, unpack, string, table, tostring
local Object, Exception = require"luv.oop".Object, require"luv.exceptions".Exception
local try = try

module(...)

local TestCase = Object:extend{
	__tag = .....".TestCase",
	Exception = Exception:extend{__tag = .....".Exception"},
	assertTrue = function (test) if not test then Exception"assertTrue failed":throw() end end,
	assertFalse = function (test) if test then Exception"assertFalse failed":throw() end end,
	assertEquals = function (first, second) if first ~= second then Exception"assertEquals failed":throw() end end,
	assertNotEquals = function (first, second) if first == second then Exception"assertNotEquals failed":throw() end end,
	assertNil = function (val) if val ~= nil then Exception"assertNil failed":throw() end end,
	assertNotNil = function (val) if val == nil then Exception"assertNotNil failed":throw() end end,
	assertThrows = function (func, ...)
		local args = {...}
		try(function()
			func(unpack(args))
		end):elseDo(function()
			Exception"assertThrows failed":throw()
		end)
	end,
	assertNotThrows = function (func, ...)
		func(...)
	end,
	setUp = function (self) end,
	tearDown = function (self) end,
	run = function (self)
		local stat = {total = 0, executed = 0, failed = 0, time = os.clock(), methods = {}}
		local function errorHandler (e)
			stat.failed = stat.failed+1
			io.write("\nException: ", e.message, e.trace)
		end
		local function runTest (self, test)
			--setfenv(test, self)
			self:setUp()
			test(self)
			self:tearDown()
			stat.executed = stat.executed+1
		end
		for key, val in pairs(self) do
			if string.find(key, "test", 1, true) and type(val) == "function" then
				stat.total = stat.total+1
				table.insert(stat.methods, key)
				io.write(key, ", ")
				try(runTest, self, self[key]):catch(Exception, errorHandler):throw()
			end
		end
		if stat.total ~= 0 then
			if stat.failed == 0 then
				io.write("\n--\nPASS ", stat.total, " tests")
			else
				io.write("\n--\nFAIL ", stat.failed, "/", stat.total, " tests")
			end
			io.write(" in ", os.clock()-stat.time, " sec")
		end
		return stat.total == 0 or (stat.total ~= 0 and stat.failed == 0)
	end
}

local TestSuite = Object:extend{
	__tag = .....".TestSuite",
	init = function (self, ...)
		self.tests = {...}
	end,
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
			local t = require(test)
			io.write(test, ": ")
			if t.isObject then
				runTest(t)
			else
				local testCase
				for _, testCase in pairs(t) do
					runTest(testCase)
				end
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

return {
	TestCase = TestCase,
	TestSuite = TestSuite
}
