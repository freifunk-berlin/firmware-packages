local uci = require "luci.model.uci".cursor()
local fs = require "nixio.fs"

f = SimpleForm("ffvpn","","")
f.submit = "Next"
f.cancel = "Back"
f.reset = false

css = f:field(DummyValue, "css", "")
css.template = "freifunk/assistent/snippets/css"

vpninfo = f:field(DummyValue, "apinfo", "")
vpninfo.template = "freifunk/assistent/snippets/vpninfo"

local cert = f:field(FileUpload, "cert", translate("Local Certificate"),"freifunk_client.crt")
cert.default="/etc/openvpn/freifunk_client.crt"
cert.rmempty = false
cert.optional = false

local key = f:field(FileUpload, "key", translate("Local Key"),"freifunk_client.key")
key.default="/etc/openvpn/freifunk_client.key"
key.rmempty = false
key.optional = false

apinfo = f:field(DummyValue, "apinfo", "")
apinfo.template = "freifunk/assistent/snippets/apinfo"

local private_ap = f:field(Flag, "private_ap", "privater Access Point")
private_ap.rmempty = false
if uci:get_first("ffwizard", "settings", "private_ap") == "1" then
  private_ap.enabled = "1"
end

local private_ap_ssid = f:field(Value, "private_ap_ssid", "SSID", "")
function private_ap_ssid.cfgvalue(self, section)
  return uci:get("ffwizard", "settings", "private_ap_ssid")
end

local private_ap_key = f:field(Value, "private_ap_key", "Passwort", "")
function private_ap_key.cfgvalue(self, section)
  return uci:get("ffwizard", "settings", "private_ap_key")
end

private_ap_js = f:field(DummyValue, "private_ap_js", "")
private_ap_js.template = "freifunk/assistent/snippets/private_ap_js"

main = f:field(DummyValue, "openvpnconfig", "", "")
main.forcewrite = true

function main.parse(self, section)
  local fvalue = "1"
  if self.forcewrite then
    self:write(section, fvalue)
  end
end

function main.write(self, section, value)

  uci:set("ffwizard", "settings", "sharenet", 1)

  uci:section("openvpn", "openvpn", "ffvpn", {
    --persist_tun='0',
    enabled='1'
  })

  fs.copy("/lib/uci/upload/cbid.ffvpn.1.cert","/etc/openvpn/freifunk_client.crt")
  fs.copy("/lib/uci/upload/cbid.ffvpn.1.key","/etc/openvpn/freifunk_client.key")

  private_ap = private_ap:formvalue(section)
  if private_ap then
    uci:set("ffwizard", "settings", "private_ap", "1")
    uci:set("ffwizard", "settings", "private_ap_ssid", private_ap_ssid:formvalue(section))
    uci:set("ffwizard", "settings", "private_ap_key", private_ap_key:formvalue(section))
  end

  uci:save("openvpn")
  uci:save("ffwizard")

  -- I need to commit this here, don't know why I can not do this in apply changes
  uci:commit("openvpn")

end

function f.handle(self, state, data)
  if state == FORM_VALID then
    luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/wireless"))
  end
end

function f.on_cancel()
  luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/decide"))
end

return f
