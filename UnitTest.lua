Object, Exception = require"ProtOo", require"Exception"

module(..., package.seeall)

local UnitTest = Object:extend{

	Exception = Exception:extend{},

	assertTrue = function (test) if not test then Exception:new"assertTrue failed":throw() end end,
	assertFalse = function (test) if test then Exception:new"assertFalse failed":throw() end end,
	assertEquals = function (first, second) if first ~= second then Exception:new"assertEquals failed":throw() end end,
	assertNotEquals = function (first, second) if first == second then Exception:new"assertNotEquals failed":throw() end end,
	assertNil = function (val) if val ~= nil then Exception:new"assertNil failed":throw() end end,
	assertNotNil = function (val) if val == nil then Exception:new"assertNotNil failed":throw() end end,
	assertThrows = function (func, ...)
		local args = {...}
		try(function()
			func(unpack(args))
		end):elseDo(function()
			Exception:new"assertThrows failed":throw()
		end)
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
			setfenv(test, self)
			self:setUp()
			test(self)
			self:tearDown()
			stat.executed = stat.executed+1
		end
		for key, val in pairs(self) do
			if string.find(key, "test", 1, true) and type(val) == "function" then
				stat.total = stat.total+1
				table.insert(stat.methods, key)
				try(runTest, self, self[key]):catch(Exception, errorHandler):throw()
			end
		end
		if stat.total ~= 0 then
			if stat.failed == 0 then
				io.write("\n--\nPASS ", stat.total, " tests (")
			else
				io.write("\n--\nFAIL ", stat.failed, "/", stat.total, " tests (")
			end
			local first = true
			for _, method in ipairs(stat.methods) do
				if first then
					first = false
				else
					io.write", "
				end
				io.write(method)
			end
			io.write(") in ", os.clock()-stat.time, " sec")
		end
		return stat.total == 0 or (stat.total ~= 0 and stat.failed == 0)
	end
}

return UnitTest