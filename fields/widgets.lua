local tostring = tostring
local Widget, html = require"luv".Widget, require"luv.utils.html"

module(...)

local Input = Widget:extend{
	__tag = .....".Input",
	tail = "",
	render = function (self, name, field)
		return [[<input type="]]..self.type..[[" name="]]..html.escape(name)..[[" id="]]..html.escape(field:getId())..[[" value="]]..html.escape(tostring(field:getValue() or field:getDefaultValue() or ""))..[["]]..self.tail..[[ />]]
	end
}

local TextInput = Input:extend{
	__tag = .....".TextInput",
	type = "text",
	render = function (self, name, field)
		self.tail = [[ maxlength="]]..field:getMaxLength()..[["]]
		return Input.render(self, name, field)
	end
}

local HiddenInput = TextInput:extend{
	__tag = .....".TextInput",
	type = "hidden"
}

local Button = Input:extend{
	__tag = .....".Button",
	type = "button"
}

local SubmitButton = Button:extend{
	__tag = .....".SubmitButton",
	type = "submit"
}

return {
	TextInput = TextInput,
	HiddenInput = HiddenInput,
	Button = Button,
	SubmitButton = SubmitButton
}
