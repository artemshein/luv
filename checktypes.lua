local type, table, unpack, error, ipairs, select, io = type, table, unpack, error, ipairs, select, io
local debug = debug

module(...)

local function expect (valType, value)
	if "table" == type(valType) and valType.isA then
		if "table" ~= type(value) or not value.isA or not value:isA(valType) then
			error("not a valid object given "..debug.traceback("", 3))
		end
	else
		if type(value) ~= valType then
			error("expected "..valType..", "..type(value).." given "..debug.traceback("", 3))
		end
	end
end

local function checkTypes (...)
	local total, params, func, result, resultFlag, args = select("#", ...), {}, nil, {}, false, {select(1, ...)}
	for i = 1, total do
		local param = args[i]
		if not resultFlag then
			if "function" == type(param) then
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
			if param then expect(param, args[i]) end
		end
		-- Call
		local realResult = {func(...)}
		-- Test result
		for i, res in ipairs(result) do
			if res then expect(res, realResult[i]) end
		end
		return unpack(realResult)
	end
end

return {expect=expect;checkTypes=checkTypes}
