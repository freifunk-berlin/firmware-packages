local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local util = require "luci.util"
local tools = require "luci.tools.freifunk.assistent.tools"
local sys = require "luci.sys"
local fs = require "nixio.fs"

local device_l = {
  "wifi",
  "wl",
  "wlan",
  "radio"
}
local netname = "wireless"
local ifcfgname = "wlan"
local community = "profile_"..uci:get("freifunk", "community", "name")
local sharenet = uci:get("ffwizard", "settings", "sharenet")

f = SimpleForm("ffwizard", "", "")
f.submit = "Next"
f.cancel = "Back"
f.reset = false

css = f:field(DummyValue, "css", "")
css.template = "freifunk/assistent/snippets/css"

local wifi_tbl = {}
uci:foreach("wireless", "wifi-device",
  function(section)
    local device = section[".name"]
    wifi_tbl[device] = {}
    local meship = f:field(Value, "meship_" .. device, device:upper() .. " Mesh IP", "")
    meship.rmempty = false
    meship.datatype = "ip4addr"
    function meship.cfgvalue(self, section)
      return uci:get("ffwizard", "settings", "meship_" .. device)
    end
    function meship.validate(self, value)
      local x = ip.IPv4(value)
      return ( x and x:is4()) and x:string() or ""
    end
    wifi_tbl[device]["meship"] = meship
  end)

meshipinfo = f:field(DummyValue, "meshinfo", "")
meshipinfo.template = "freifunk/assistent/snippets/meshipinfo"

ssid = f:field(Value, "ssid", "Freifunk SSID", "")
ssid.rmempty = false
function ssid.cfgvalue(self, section)
  return uci:get("ffwizard", "settings", "ssid")
    or uci:get(community, "profile", "ssid")
end

dhcpmesh = f:field(Value, "dhcpmesh", "Addressraum", "")
dhcpmesh.rmempty = false
dhcpmesh.datatype = "ip4addr"
function dhcpmesh.cfgvalue(self, section)
  return uci:get("ffwizard","settings", "dhcpmesh")
end
function dhcpmesh.validate(self, value)
  local x = ip.IPv4(value)
  return ( x and x:minhost() and x:prefix() < 32) and x:string() or ""
end

apinfo = f:field(DummyValue, "apinfo", "")
apinfo.template = "freifunk/assistent/snippets/apinfo"

main = f:field(DummyValue, "netconfig", "", "")
main.forcewrite = true
function main.parse(self, section)
  local fvalue = "1"
  if self.forcewrite then
    self:write(section, fvalue)
  end
end
function main.write(self, section, value)
  if (sharenet == "2") then
    --share internet was not enabled before, set to false now
    uci:set("ffwizard", "settings", "sharenet", 0)
    uci:save("ffwizard")
  end

  -- store wizard data to fill fields if wizard is rerun
  uci:set("ffwizard", "settings", "ssid", ssid:formvalue(section))
  uci:set("ffwizard", "settings", "dhcpmesh", dhcpmesh:formvalue(section))

  if (string.len(ssid:formvalue(section)) == 0
    or string.len(dhcpmesh:formvalue(section)) == 0) then
    -- form is not valid
    return
  end

  uci:foreach("wireless", "wifi-device",
    function(sec)
      local device = sec[".name"]

      -- store wizard data to fill fields if wizard is rerun
      uci:set("ffwizard", "settings",
        "meship_" .. device, wifi_tbl[device]["meship"]:formvalue(section)
      )

      if (string.len(wifi_tbl[device]["meship"]:formvalue(section)) == 0) then
        -- form is not valid
        return
      end

      cleanup(device)

      --OLSR CONFIG device
      local olsrifbase = {}
      olsrifbase.interface = calcnif(device)
      olsrifbase.ignore = "0"
      uci:section("olsrd", "Interface", nil, olsrifbase)

      --OLSR6 CONFIG device
      local olsrifbase6 = {}
      olsrifbase6.interface = calcnif(device)
      olsrifbase6.ignore = "0"
      uci:section("olsrd6", "Interface", nil, olsrifbase6)

      --FIREWALL CONFIG device
      tools.firewall_zone_add_interface("freifunk", calcnif(device))

      --WIRELESS CONFIG device
      local devconfig = uci:get_all("freifunk", "wifi_device") or {}
      util.update(devconfig, uci:get_all(community, "wifi_device") or {})
      devconfig.channel = getchannel(device)
      devconfig.hwmode = calchwmode(devconfig.channel, sec)
      devconfig.doth = calcdoth(devconfig.channel)
      devconfig.htmode = calchtmode(devconfig.channel)
      devconfig.country = 'DE'
      devconfig.chanlist = calcchanlist(devconfig.channel)
      uci:tset("wireless", device, devconfig)

      --WIRELESS CONFIG ad-hoc
      local ifconfig = uci:get_all("freifunk", "wifi_iface")
      util.update(ifconfig, uci:get_all(community, "wifi_iface") or {})
      ifconfig.device = device
      ifconfig.mcast_rate = ""
      ifconfig.network = calcnif(device)
      ifconfig.ifname = calcifcfg(device).."-".."adhoc".."-"..calcpre(devconfig.channel)
      ifconfig.mode = "adhoc"
      ifconfig.ssid = uci:get(community, "ssidscheme", devconfig.channel)
      ifconfig.bssid = uci:get(community, "bssidscheme", devconfig.channel)
      uci:section("wireless", "wifi-iface", nil, ifconfig)

      --NETWORK CONFIG ad-hoc
      local node_ip = wifi_tbl[device]["meship"]:formvalue(section)
      node_ip = ip.IPv4(node_ip)
      local prenetconfig = {}
      prenetconfig.proto = "static"
      prenetconfig.ipaddr = node_ip:host():string()
      prenetconfig.netmask = uci:get(community,'interface','netmask')
      prenetconfig.ip6assign = 64
      uci:section("network", "interface", calcnif(device), prenetconfig)

      --WIRELESS CONFIG ap
      uci:section("wireless", "wifi-iface", nil, {
        device=device,
        mode="ap",
        encryption="none",
        network="dhcp",
        ifname=calcifcfg(device).."-dhcp-"..calcpre(devconfig.channel),
        ssid=ssid:formvalue(section)
      })

      uci:save("firewall")
      uci:save("olsrd")
      uci:save("olsrd6")
      uci:save("wireless")
      uci:save("network")

    end)


  local dhcpmeshnet = dhcpmesh:formvalue(section)
  dhcpmeshnet = ip.IPv4(dhcpmeshnet)

  --only do this if user entered cidr
  if (dhcpmeshnet:prefix() < 32) then
    --NETWORK CONFIG bridge for wifi APs
    local prenetconfig =  {}
    prenetconfig.dns=uci:get(community, "interface", "dns")
    prenetconfig.type="bridge"
    prenetconfig.proto="static"
    prenetconfig.ipaddr=dhcpmeshnet:minhost():string()
    prenetconfig.netmask=dhcpmeshnet:mask():string()
    prenetconfig.ip6assign="64"
    -- use ifname from dhcp bridge on a consecutive run of assistent
    prenetconfig.ifname=uci:get("network", "lan", "ifname") or uci:get("network", "dhcp", "ifname")
    uci:section("network", "interface", "dhcp", prenetconfig)

    --NETWORK CONFIG remove lan bridge because ports a part of dhcp bridge now
    uci:delete("network", "lan")

    --DHCP CONFIG change ip of frei.funk domain
    uci:set("dhcp", "frei_funk", "ip", dhcpmeshnet:minhost():string())

    --DHCP CONFIG bridge for wifi APs
    local dhcpbase = uci:get_all("freifunk", "dhcp") or {}
    util.update(dhcpbase, uci:get_all(community, "dhcp") or {})
    dhcpbase.interface = "dhcp"
    dhcpbase.force = 1
    dhcpbase.ignore = 0
    uci:section("dhcp", "dhcp", "dhcp", dhcpbase)
    uci:set_list("dhcp", "dhcp", "dhcp_option", "119,olsr")

    --OLSR CONFIG announce dhcp bridge subnet (HNA)
    uci:section("olsrd", "Hna4", nil, {
      netmask = dhcpmeshnet:mask():string(),
      netaddr = dhcpmeshnet:network():string()
    })
  end

  uci:save("dhcp")
  uci:save("olsrd")
  uci:save("olsrd6")
  uci:save("network")
  uci:save("ffwizard")
end

function f.on_cancel()
  luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/decide"))
end

function f.handle(self, state, data)
  --how can I read form data here to get rid of this main field??
  if state == FORM_VALID then
    luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/applyChanges"))
  end
end

function calcpre(channel)
  -- calculates suffix of wifi interface (like 2 or 5)
  return (channel > 0 and channel <= 14) and 2 or 5
end

function calcchanlist(channel)
  local chanlist
  if channel >= 100 and channel <= 140 then
    chanlist = "100 104 108 112 116 120 124 128 132 136 140"
  else
    chanlist =""
  end
  return chanlist
end

function calcdoth(channel)
  -- doth activates 802.11h (radar detection)
  return (channel >= 52 and channel <= 140) and "1" or "0"
end

function calchtmode(channel)
  local htmode
  if channel >= 100 and channel <= 140 then
    htmode = "HT20"

  else
    local ht40plus = {
      1,2,3,4,5,6,7,
      36,44,52,60
    }
    for i, v in ipairs(ht40plus) do
      if v == channel then
        htmode = 'HT40+'
      end
    end
    local ht40minus = {
      8,9,10,11,12,13,14,
      40,48,56,64
    }
    for i, v in ipairs(ht40minus) do
      if v == channel then
        htmode = 'HT40-'
      end
    end

  end
  return htmode
end

function calchwmode(channel, sec)
  local has_n = ""

  if sec.type == "mac80211" then
    hwmode = sec.hwmode
    if hwmode and string.find(hwmode, "n") then
      has_n = "n"
    end
  end

  return "11" .. has_n .. ((channel > 0 and channel <= 14) and "g" or "a")
end

function getchannel(device)
  --local wifi require "luci.sys.wifi"
  --wifi.channels(device) --from luci reference: does not work
  --sys.wifi.getiwinfo(device) --from sys.lua: does not work
  -- >:( why?

  local iwinfo = require "iwinfo"
  local type = iwinfo.type(device)
  local something = iwinfo[type]
  local freqlist = something.freqlist(device)

  --TODO read channels from profile
  local r_channel
  if (freqlist[1].mhz > 2411 and freqlist[1].mhz < 2484) then
    --this is 2.4 Ghz
    r_channel = 13
  end
  if (freqlist[1].mhz > 5179 and freqlist[1].mhz < 5701) then
    --this is 5 Ghz
    r_channel = 36
  end
  tools.logger("channel for device "..device.." is "..tostring(r_channel))
  return r_channel
end

function calcnif(device)
  local nif
  for i, v in ipairs(device_l) do
    if string.find(device, v) then
      nif = string.gsub(device, v, netname)
    end
  end
  return nif
end

function calcifcfg(device)
  local ifcfg
  for i, v in ipairs(device_l) do
    if string.find(device, v) then
      ifcfg = string.gsub(device, v, ifcfgname)
    end
  end
  return ifcfg
end

function cleanup(device)
  tools.wifi_delete_ifaces(device)
  tools.wifi_delete_ifaces("wlan")
  uci:delete("network", device .. "dhcp")
  uci:delete("network", device)
  local nif = calcnif(device)
  tools.firewall_zone_remove_interface("freifunk", device)
  tools.firewall_zone_remove_interface("freifunk", nif)
  uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
  uci:delete_all("luci_splash", "iface", {network=nif.."dhcp", zone="freifunk"})
  uci:delete("network", nif .. "dhcp")
  uci:delete("network", nif)
  uci:delete("dhcp", device)
  uci:delete("dhcp", device .. "dhcp")
  uci:delete("dhcp", nif)
  uci:delete("dhcp", nif .. "dhcp")
end

return f
