require "luv.string"
local tostring, debug, io = tostring, debug, io
local string = string
local Widget, html = require"luv".Widget, require"luv.utils.html"

module(...)

local Input = Widget:extend{
	__tag = .....".Input",
	tail = "",
	render = function (self, field, form)
		return [[<input type="]]..self.type..[[" name="]]..html.escape(field:getName())..[[" id="]]..html.escape(form:getId()..string.capitalize(field:getId()))..[[" value="]]..html.escape(tostring(field:getValue() or field:getDefaultValue() or ""))..[["]]..self.tail..[[ />]]
	end
}

local TextInput = Input:extend{
	__tag = .....".TextInput",
	type = "text",
	render = function (self, field, form)
		self.tail = [[ maxlength="]]..field:getMaxLength()..[["]]
		return Input.render(self, field, form)
	end
}

local HiddenInput = TextInput:extend{
	__tag = .....".HiddenInput",
	type = "hidden"
}

local PasswordInput = TextInput:extend{
	__tag = .....".PasswordInput",
	type = "password"
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
	PasswordInput = PasswordInput,
	Button = Button,
	SubmitButton = SubmitButton
}
