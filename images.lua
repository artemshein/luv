local string = require 'luv.string'
local type, pairs, ipairs = type, pairs, ipairs
local Object = require 'luv.oop'.Object
local fs = require 'luv.fs'

module(...)

local Png = Object:extend{
	__tag = .....'.Png';
	init = function (self, path)
	end;
}

local Gif = Object:extend{
	__tag = .....'.Gif';
	init = function (self, path)
	end;
}

local Jpeg = Object:extend{
	__tag = .....'.Gif';
	init = function (self, path)
	end;
}

local function detectFormat (filepath)
	local signatures =
	{
		png=string.char(137, 80, 78, 71, 13, 10, 26, 10);
		gif={'GIF87a';'GIF89a'};
		jpeg=string.char(0xFF, 0xD8);
	}
	local data = fs.File(filepath):openReadAndClose '*a'
	for format, signs in pairs(signatures) do
		if 'table' == type(signs) then
			for _, sign in ipairs(signs) do
				if string.slice(data, 1, #sign) == sign then
					return format
				end
			end
		elseif string.slice(data, 1, #signs) == signs then
			return format
		end
	end
end

return
{
	detectFormat=detectFormat;
}
