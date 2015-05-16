local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local util = require "luci.util"
local tools = require "luci.tools.freifunk.assistent.tools"
local sys = require "luci.sys"
local fs = require "nixio.fs"
local ipkg = require "luci.model.ipkg"

local html = require "luci.http"
if html.formvalue("sharenet", true) == "0" then
  uci:set("ffwizard","settings","sharenet", 2)
  uci:save("ffwizard")
end

f = SimpleForm("ffwizard", "", "")
f.submit = "Next"
f.cancel = "Back"
f.reset = false

css = f:field(DummyValue, "css", "")
css.template = "freifunk/assistent/snippets/css"

enableStatsInfo = f:field(DummyValue, "statsInfo", "")
enableStatsInfo.template = "freifunk/assistent/snippets/enableStats"

enableStats = f:field(Flag, "stats", "Monitoring anschalten")
enableStats.default = 0 -- this does not work
function enableStats.cfgvalue(self, section)
  return tostring(uci:get("ffwizard", "settings" , "enableStats")) or "0"
end

apinfo = f:field(DummyValue, "apinfo", "")
apinfo.template = "freifunk/assistent/snippets/apinfo"

local private_ap = f:field(Flag, "private_ap", "privater Access Point")
function private_ap.cfgvalue(self, section)
  return tostring(uci:get_first("ffwizard", "settings", "private_ap")) or "0"
end

-- main field needs to be defined before ssid and key or validation of these fields does not work properly
main = f:field(DummyValue, "optionalConfigs", "", "")
main.forcewrite = true
function main.parse(self, section)
  local fvalue = "1"
  if self.forcewrite then
    self:write(section, fvalue)
  end
end

local private_ap_ssid = f:field(Value, "private_ap_ssid", "SSID", "")
private_ap_ssid:depends("private_ap",1)
private_ap_ssid.rmempty = false
function private_ap_ssid.cfgvalue(self, section)
  return uci:get("ffwizard", "settings", "private_ap_ssid")
end

local private_ap_key = f:field(Value, "private_ap_key", "Passwort", "")
private_ap_key:depends("private_ap",1)
private_ap_key.rmempty = false
function private_ap_key.cfgvalue(self, section)
  return uci:get("ffwizard", "settings", "private_ap_key")
end
function private_ap_key.validate(self, value)
  return value and value:len() > 7
end

function main.write(self, section, value)
  uci:set("ffwizard", "settings", "enableStats", enableStats:formvalue(section) or "0")
  private_ap = private_ap:formvalue(section) or "0"
  uci:set("ffwizard", "settings", "private_ap", private_ap)
  if private_ap == "1" then
    uci:set("ffwizard", "settings", "private_ap_ssid", private_ap_ssid:formvalue(section))
    uci:set("ffwizard", "settings", "private_ap_key", private_ap_key:formvalue(section))
  else
    uci:set("ffwizard", "settings", "private_ap_ssid", "")
    uci:set("ffwizard", "settings", "private_ap_key", "")
  end
  uci:save("ffwizard")
end

function f.on_cancel()
  luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/decide"))
end

function f.handle(self, state, data)
  --how can I read form data here to get rid of this main field??
  if state == FORM_VALID then
    luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/wireless"))
  end
end

return f
