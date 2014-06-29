local uci = require "luci.model.uci".cursor()
local tools = require "luci.tools.freifunk.assistent.ffwizard"
f = SimpleForm("ffwizward", "", "")
--change button texts
f.submit = "Next"
f.cancel = "Skip"
--hide reset button	
f.reset = false

css = f:field(DummyValue, "css", "")
css.template = "freifunk/assistent/snippets/css"

welcome = f:field(DummyValue, "welcome", "")
welcome.template = "freifunk/assistent/snippets/welcome" 
 
pw1 = f:field(Value, "pw1", translate("Password"))
pw1.password = true
 
pw2 = f:field(Value, "pw2", translate("Confirmation"))
pw2.password = true
function pw2.validate(self, value, section)
	return pw1:formvalue(section) == value and value
end

function f.handle(self, state, data)
	if state == FORM_VALID then
		if data.pw1 and data.pw2 then
			local stat = luci.sys.user.setpasswd("root", data.pw1) == 0
		end
		data.pw1 = nil
		data.pw2 = nil
		luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/generalInfo"))
	end
end

-- don't know how to trigger reset button, so I use skip button instead
function f.on_cancel()
	tools.logger("skip change password")
	luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/generalInfo"))
end

return f
 
