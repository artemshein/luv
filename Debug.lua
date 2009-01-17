local Debug, Table = debug or {}, require"Luv.Table"

module(..., package.seeall)

-- trace & untrace are stolen from book and should be removed or rewrited in future

local Depth

local function GetInfo(StackLvl, WithLineNum)
	StackLvl = StackLvl + 1
	local Ret
	local Info = Debug.getinfo(StackLvl, "nlS")
	if not Info then
		Ret = "nowhere"
	else
		local Name, What, LineNum, ShortSrc = Info.name, Info.what, Info.currentline, Info.short_src
		if What == "tail" then
			Ret = "overwritten stack frame"
		else
			if not Name then
				if What == "main" then
					Name = "chunk"
				else
					Name = What .. " function"
				end
			end
			if Name == "C function" then
				Ret = Name
			else
				LineNum = LineNum >= 1 and LineNum
				if WithLineNum and LineNum then
					Ret = Name .. " (" .. ShortSrc .. ", line " .. LineNum .. ")"
				else
					Ret = Name .. " (" .. ShortSrc .. ")"
				end
			end
		end
	end
	return Ret
end

local function Indent(N)
	return string.rep(" ", N)
end

local function Hook(Event)
	local Running = GetInfo(2)
	local Caller = GetInfo(3, true)
	if Event == "call" then
		Depth = Depth + 1
		io.stderr:write(Indent(Depth), "calling ", Running, " from ", Caller, "\n")
	else
		local RetType
		if Event == "return" then
			RetType = "returning from "
		elseif Event == "tail return" then
			RetType = "tail-returning from "
		end
		io.stderr:write(Indent(Depth), RetType, Running, " to ", Caller, "\n")
		Depth = Depth - 1
	end
end

function Debug.trace()
	if Depth then
		return
	end

	Depth = 1
	for Info in function() return Debug.getinfo(Depth, "n") end	do
		Depth = Depth + 1
	end
	Depth = Depth - 2
	Debug.sethook(Hook, "cr")
end

function Debug.untrace()
	Debug.sethook()
	Depth = nil
end

function Debug.dump (obj, depth, tab, seen)
	local tab = tab or ""
	local depth = depth or 10
	local seen = seen or {}
	if type(obj) == "nil" then
		io.write"nil"
	elseif obj == true then
		io.write"true"
	elseif obj == false then
		io.write"false"
	elseif type(obj) == "number" then
		io.write(obj)
	elseif type(obj) == "string" then
		io.write("\"", obj, "\"")
	elseif type(obj) == "table" then
		local tag = rawget(obj, "__tag")
		if tag then
			io.write(tag)
		else
			io.write(tostring(obj))
		end
		if Table.find(seen, obj) then
			io.write" RECURSION"
		elseif 0 ~= depth then
			Table.insert(seen, obj)
			io.write"{\n"
			local ntab = tab.."  "
			for key, val in pairs(obj) do
				if key ~= "__tag" then
					io.write(ntab, key, " = ")
					Debug.dump(val, depth-1, ntab, seen)
					io.write",\n"
				end
			end
			if getmetatable(obj) then
				io.write(ntab, "__metatable = ")
				Debug.dump(getmetatable(obj), depth-1, ntab, seen)
				io.write"\n"
			end
			io.write(tab, "}")
			Table.removeValue(seen, obj)
		end
	elseif type(obj) == "function" then
		io.write(tostring(obj))
	else
		io.write(type(obj))
	end
end

return Debug
