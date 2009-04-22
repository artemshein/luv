local Object = require"luv.oop".Object
local require = require
local debug = debug

module(...)

local Version = Object:extend{
	__tag = .....".Version",
	minor = 0,
	patch = 0,
	state = "stable",
	init = function (self, major, minor, patch, state, rev, codename)
		self.major = major
		self.minor = minor
		self.patch = patch
		if state then
			self.state = state
		end
		self.rev = rev
		self.codename = codename
	end,
	full = function (self)
		local res = self.major.."."..self.minor
		if 0 ~= self.patch then
			res = res.."."..self.patch
		end
		if "stable" ~= self.state then
			res = res..self.state
		end
		if self.rev then
			res = res.." rev"..self.rev
		end
		if self.codename then
			res = res.." "..self.codename
		end
		return res
	end,
	__tostring = function (self) return self:full() end
}

local sendEmail = function (from, to, subject, body, server)
	local smtp, mime = require "socket.smtp", require "mime"
	return smtp.send{
		from = from;
		rcpt = to;
		source = smtp.message{
			headers = {
				from = from;
				to = to;
				subject = "=?utf-8?b?"..(mime.b64(subject)).."?=";
			};
			body = {{
				headers = {
					["content-type"] = 'text/plain; charset="utf-8"';
					["content-transfer-encoding"] = "BASE64";
				};
				body = (mime.b64(body));
			}};
		};
		server = server;
	}
end

return {
	Version = Version;
	sendEmail=sendEmail;
}
