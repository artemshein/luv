local dofile, tostring, assert, type = dofile, tostring, assert, type
local require, ipairs = require, ipairs
local string = require"luv.string"
local Object = require"luv.oop".Object
local fs = require"luv.fs"

module(...)

local property = Object.property

local I18n = Object:extend{
	__tag = .....".I18n";
	lang = property"string";
	dir = property(fs.Dir);
	msgs = property"table";
	_tryToLoadLang = function (self, lang)
		local f = fs.File(self:dir() / (lang..".lua"))
		if f:exists() then
			self:lang(lang)
			self:msgs(assert(dofile(tostring(f:path()))))
			string.tr = function (str) return self:msgs()[str] or str end
			return true
		end
	end;
	init = function (self, dir, langOrWsApi)
		self:dir("table" ~= dir and fs.Dir(dir) or dir)
		if "string" ~= type(langOrWsApi) then
			langOrWsApi = langOrWsApi:requestHeader"HTTP_ACCEPT_LANGUAGE"
			if langOrWsApi then
				langs = langOrWsApi:explode","
				for _, lang in ipairs(langs) do
					if lang:find";" then lang = lang:slice(1, lang:find";"-1) end
					if 0 ~= #lang and self:_tryToLoadLang(lang) then
						break
					end
				end
			end
		else
			self:_tryToLoadLang(langOrWsApi)
		end
	end;
}

return {I18n=I18n}
