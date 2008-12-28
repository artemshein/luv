local Widget, Field, String = require"Widgets.Widget", require"Fields.Field", require"String"
local Debug = require"Debug"

module(...)

local InputField = Widget:extend{
	__tag = "Widgets.InputField",
	
	init = function (self, type)
		self.type = type or "text"
	end,
	render = Widget.checkTypes(Widget, Field, function (self, field)
		return String.format([[<input type="%s" name="%s" value="%s" />]], self.type, field:getName(), String.htmlEscape(field:getValue() or field:getDefaultValue() or ""))
	end, "string")
}

return InputField