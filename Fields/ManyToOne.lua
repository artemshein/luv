local require, type, io = require, type, io
local Fields, Exception, Debug = from"Luv":import("Fields", "Exception", "Debug")

module(...)

return Fields.Reference:extend{
	__tag = .....".ManyToOne",

	getValue = function (self)
		local valType = type(self.value)
		if valType ~= nil and valType ~= "table" then
			self:setValue(self:getRefModel():find(self.value))
		end
		return Fields.Reference.getValue(self)
	end,
	setValue = function (self, value)
		if type(value) == "table" and not value:isKindOf(self:getRefModel()) then
			Exception("Instance of "..self.ref.." or nil required!"):throw()
		elseif value ~= nil and type(value) ~= "table" and not self:getRefModel():getPk():validate(value) then
			Exception"Invalid field value!":throw()
		end
		return Fields.Reference.setValue(self, value)
	end,
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	createBackLink = function (self)
		return Fields.OneToMany{references=self:getContainer()}
	end
}
