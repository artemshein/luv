local type, table, unpack, error, ipairs, select, io = type, table, unpack, error, ipairs, select, io
local debug = debug

module(...)

local function expect (value, valType)
	if valType and type(value) ~= valType then
		error("Expected "..valType.." not "..type(value).."! "..debug.traceback())
	end
end

local function checkTypes (...)
	local total, params, func, result, resultFlag, args = select("#", ...), {}, nil, {}, false, {select(1, ...)}
	for i = 1, total do
		local param = args[i]
		if not resultFlag then
			if type(param) == "function" then
				resultFlag = true
				func = param
			else
				table.insert(params, param or false)
			end
		else
			table.insert(result, param or false)
		end
	end
	return function (...)
		local args = {select(1, ...)}
		-- Test input
		for i, param in ipairs(params) do
			expect(args[i], param)
		end
		-- Call
		local realResult = {func(...)}
		-- Test result
		for i, res in ipairs(result) do
			expect(realResult[i], res)
		end
		return unpack(realResult)
	end
end

return {expect=expect;checkTypes=checkTypes}
