local dofile, tostring, assert, type, os = dofile, tostring, assert, type, os
local require, ipairs, error, debug, io = require, ipairs, error, debug, io
local string = require"luv.string"
local Object = require"luv.oop".Object
local fs = require"luv.fs"

module(...)

local property = Object.property

local I18n = Object:extend{
	__tag = .....".I18n";
	lang = property"string";
	dir = property(fs.Dir);
	_msgs = {};
	msgs = property"table";
	_tryToLoadLang = function (self, lang, globalFlag)
		local country
		if lang:find"-" then
			lang, country = lang:split"-"
		end
		local f = fs.File(self:dir() / (lang..".lua"))
		if f:exists() then
			self:lang(lang)
			self:msgs(assert(dofile(tostring(f:path()))))
			if globalFlag then
				os.setlocale(lang.."_"..(country and country:upper() or lang:upper())..".utf8")
				string.tr = function (str) return self:msgs()[str] or str end
			end
			return true
		end
	end;
	tr = function (self, str)
		return self:msgs()[str] or str
	end;
	init = function (self, dir, langOrWsApi, globalFlag)
		if nil == globalFlag then
			globalFlag = true
		end
		self:dir("table" ~= dir and fs.Dir(dir) or dir)
		if "string" ~= type(langOrWsApi) then
			langOrWsApi = langOrWsApi:requestHeader"HTTP_ACCEPT_LANGUAGE"
			if langOrWsApi then
				langs = langOrWsApi:explode","
				for _, lang in ipairs(langs) do
					if lang:find";" then lang = lang:slice(1, lang:find";"-1) end
					if 0 ~= #lang and self:_tryToLoadLang(lang, globalFlag) then
						break
					end
				end
			end
		else
			self:_tryToLoadLang(langOrWsApi, globalFlag)
		end
	end;
}

return {I18n=I18n}
