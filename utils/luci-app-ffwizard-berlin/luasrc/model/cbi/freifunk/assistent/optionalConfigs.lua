local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local util = require "luci.util"
local tools = require "luci.tools.freifunk.assistent.tools"
local sys = require "luci.sys"
local fs = require "nixio.fs"
local ipkg = require "luci.model.ipkg"

f = SimpleForm("ffwizard", "", "")
f.submit = "Next"
f.cancel = "Back"
f.reset = false

css = f:field(DummyValue, "css", "")
css.template = "freifunk/assistent/snippets/css"

enableStats = f:field(Flag, "stats", "Monitoring anschalten")
enableStats.default = 0 -- this does not work
function enableStats.cfgvalue(self, section)
  return tostring(uci:get("ffwizard", "settings" , "enableStats")) or "0"
end
enableStatsInfo = f:field(DummyValue, "statsInfo", "")
enableStatsInfo.template = "freifunk/assistent/snippets/enableStats"

main = f:field(DummyValue, "optionalConfigs", "", "")
main.forcewrite = true
function main.parse(self, section)
  local fvalue = "1"
  if self.forcewrite then
    self:write(section, fvalue)
  end
end

function main.write(self, section, value)
  uci:set("ffwizard", "settings", "enableStats", enableStats:formvalue(section) or "0")
  uci:save("ffwizard")
end

function f.on_cancel()
  luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/wireless"))
end

function f.handle(self, state, data)
  --how can I read form data here to get rid of this main field??
  if state == FORM_VALID then
    luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/applyChanges"))
  end
end

return f
