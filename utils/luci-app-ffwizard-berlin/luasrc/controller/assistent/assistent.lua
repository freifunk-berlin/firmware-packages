local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local tools = require "luci.tools.freifunk.assistent.ffwizard"
local atools = require "luci.tools.freifunk.assistent.tools"
local ip = require "luci.ip"

local olsr = require "luci.tools.freifunk.assistent.olsr"
local firewall = require "luci.tools.freifunk.assistent.firewall"


module ("luci.controller.assistent.assistent", package.seeall)

function index()
  entry({"admin", "freifunk", "assistent"}, call("prepare"), "Freifunkassistent", 1).dependent=false
  entry({"admin", "freifunk", "assistent", "changePassword"}, form("freifunk/assistent/changePassword"), "",1)
  entry({"admin", "freifunk", "assistent", "generalInfo"}, form("freifunk/assistent/generalInfo"), "", 1)
  entry({"admin", "freifunk", "assistent", "decide"}, template("freifunk/assistent/decide"), "", 2)
  entry({"admin", "freifunk", "assistent", "sharedInternet"}, form("freifunk/assistent/shareInternet"), "", 10)
  entry({"admin", "freifunk", "assistent", "wireless"}, form("freifunk/assistent/wireless"), "", 20)
  entry({"admin", "freifunk", "assistent", "applyChanges"}, call("commit"), "", 100)
  entry({"admin", "freifunk", "assistent", "reboot"}, template("freifunk/assistent/reboot"), "", 101)
  entry({"admin", "freifunk", "assistent", "cancel"}, call("reset"), "", 102)
end

function prepare()

  --reset sharenet value, will be set in shareInternet or wireless and read in applyChanges
  uci:set("ffwizard","settings","sharenet", 2)
  uci:save("ffwizard")

  --OLSR CONFIG
  olsr.prepareOLSR()

  --FIREWALL CONFIG
  tools.prepareFirewall()

  uci:save("olsrd")
  uci:save("firewall")

  luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/changePassword"))
end

function commit()

  uci:set("ffwizard","settings","runbefore","true")
  uci:save("ffwizard")
  local sharenet = uci:get("ffwizard","settings","sharenet")

  local community = "profile_"..uci:get("freifunk","community","name")

  --change hostname to mesh ip if it is still Openwrt-something
  if (not uci:get_first("system","system","hostname") or string.sub(uci:get_first("system","system","hostname"),1,string.len("OpenWrt"))=="OpenWrt") then
    local dhcpmesh = uci:get("ffwizard","settings","dhcpmesh")
    dhcpmesh = ip.IPv4(dhcpmesh):minhost()
    uci:foreach("system", "system",
      function(section)
        local newhostname = dhcpmesh:string():gsub("%.", "-")
        uci:set("system",section[".name"],"hostname", newhostname)
      end)
  end

  --remove geo data if it is still default
  local latval = tonumber(uci:get_first("system","system","latitude"))
  local lonval = tonumber(uci:get_first("system","system","longitude"))
  local latval_com = tonumber(uci:get_first(community,"community","latitude"))
  local lonval_com = tonumber(uci:get_first(community,"community","longitude"))

  if latval and latval == 52 then
    latval = nil
  end
  if latval and latval == latval_com then
    latval = nil
  end
  if lonval and lonval == 13 then
    lonval = nil
  end
  if lonval and lonval == lonval_com then
    --this is always false?: o_0
    lonval = nil
  end
  if not lonval or not latval then
    uci:foreach("system","system",
      function(s)
        uci:delete("system", s[".name"], "latlon")
        uci:delete("system", s[".name"], "latitude")
        uci:delete("system", s[".name"], "longitude")
      end)
    uci:save("system")
  end

  firewall.configureFirewall()
  firewall.configurePolicyRouting()

  olsr.configureOLSR()
  olsr.configureOLSRPlugins()

  atools.configureWatchdog()
  atools.configureQOS()

  uci:commit("dhcp")
  uci:commit("olsrd")
  uci:commit("olsrd6")
  uci:commit("firewall")
  uci:commit("system")
  uci:commit("ffwizard")
  uci:commit("freifunk")
  uci:commit("freifunk-policyrouting")
  uci:commit("wireless")
  uci:commit("network")
  uci:commit("freifunk-watchdog")
  uci:commit("qos")


  sys.hostname(uci:get_first("system","system","hostname"))
  sys.init.enable("olsrd")
  sys.init.enable("olsrd6")
  sys.init.enable("qos")
  if (sharenet == "1") then
    sys.init.enable("freifunk-policyrouting")
    sys.exec('grep wan /etc/crontabs/root >/dev/null || echo "0 6 * * * ifup wan" >> /etc/crontabs/root')
  else
    sys.init.disable("freifunk-policyrouting")
  end

  luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/reboot"))
end

function reset()
  uci:revert("dhcp")
  uci:revert("olsrd")
  uci:revert("olsrd6")
  uci:revert("firewall")
  uci:revert("system")
  uci:revert("freifunk")
  uci:revert("freifunk-policyrouting")
  uci:revert("wireless")
  uci:revert("network")
  uci:revert("freifunk-watchdog")
  uci:revert("qos")

  uci:set("ffwizard","settings","runbefore","true")
  uci:save("ffwizard")
  uci:commit("ffwizard")

  luci.http.redirect(luci.dispatcher.build_url("/"))
end
