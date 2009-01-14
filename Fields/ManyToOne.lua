local require, Debug, type, io = require, require"Debug", type, io
local Reference, Exception = require"Fields.Reference", require"Exception"

module(...)

return Reference:extend{
	__tag = "Fields.ManyToOne",

	getValue = function (self)
		local valType = type(self.value)
		if valType ~= nil and valType ~= "table" then
			self:setValue(self:getRefModel():find(self.value))
		end
		return Reference.getValue(self)
	end,
	setValue = function (self, value)
		if type(value) == "table" and not value:isKindOf(self:getRefModel()) then
			Exception("Instance of "..self.ref.." or nil required!"):throw()
		elseif value ~= nil and type(value) ~= "table" and not self:getRefModel():getPk():validate(value) then
			Exception"Invalid field value!":throw()
		end
		return Reference.setValue(self, value)
	end,
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end
}
