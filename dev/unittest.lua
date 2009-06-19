local string = require"luv.string"
local table = require"luv.table"
local pairs, io, require, os, type, unpack, tostring = pairs, io, require, os, type, unpack, tostring
local exceptions = require 'luv.exceptions'
local Object, Exception, try = require"luv.oop".Object, exceptions.Exception, exceptions.try

module(...)

local TestCase = Object:extend{
	__tag = .....".TestCase",
	Exception = Exception:extend{__tag = .....".Exception"},
	assertTrue = function (test) if not test then Exception"assertTrue failed" end end,
	assertFalse = function (test) if test then Exception"assertFalse failed" end end,
	assertEquals = function (first, second) if first ~= second then Exception"assertEquals failed" end end,
	assertNotEquals = function (first, second) if first == second then Exception"assertNotEquals failed" end end,
	assertNil = function (val) if val ~= nil then Exception"assertNil failed" end end,
	assertNotNil = function (val) if val == nil then Exception"assertNotNil failed" end end,
	assertThrows = function (func, ...)
		local args = {...}
		try(function()
			func(unpack(args))
		end):elseDo(function()
			Exception"assertThrows failed"
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
			io.write("\nException: ", e:getMsg(), e:getTrace())
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
			Exception"No tests are defined!"
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
			if t.isKindOf then
				io.write(test, ": ")
				runTest(t)
			else
				local testCase
				for k, testCase in pairs(t) do
					io.write(test, "/", k, ": ")
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
