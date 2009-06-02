local table, ipairs = table, ipairs

module(...)

local signals = {}

local function connect (sender, signal, receiver, slot)
	local value = {receiver;slot}
	if not signals[sender] then
		signals[sender] = {[signal]={value}}
	elseif not signals[sender][signal] then
		signals[sender][signal] = {value}
	else
		table.insert(signals[sender][signal], value)
	end
end

local function disconnect (sender, signal, receiver, slot)
	local value = {receiver;slot}
	if not signals[sender] then
		return
	end
	if not signals[sender][signal] then
		return
	end
	local pos
	for i, v in ipairs(signals[sender][signal]) do
		if receiver == v[1] and slot == v[2] then
			pos = i
			break
		end
	end
	if pos then
		table.remove(signals[sender][signal], pos)
	end
end

local function emit (sender, signal, ...)
	local slots = signals[sender] and signals[sender][signal]
	if slots then
		for _, slot in ipairs(slots) do
			slot[1][slot[2]](slot[1], ...)
		end
	end
end

return {connect=connect;disconnect=disconnect;emit=emit}
