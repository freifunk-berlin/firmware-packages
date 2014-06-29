local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local util = require "luci.util"
local tools = require "luci.tools.freifunk.assistent.ffwizard"
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
--TODO set profile in general config and read here
local community = "berlin"
local external = "profile_"..community
local sharenet = uci:get("freifunk","wizard","sharenet")



f = SimpleForm("ffwizard","","")
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
		meship.rmempty = true
		meship.datatype = "ip4addr"
		function meship.cfgvalue(self, section)
			return uci:get("freifunk", "wizard", "meship_" .. device)
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
ssid.rmempty = true
function ssid.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "ssid") or uci:get(external, "profile","ssid")
end

dhcpmesh = f:field(Value, "dhcpmesh", "Addressraum", "")
dhcpmesh.rmempty = true
dhcpmesh.datatype = "ip4addr"
function dhcpmesh.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "dhcpmesh")
end
function dhcpmesh.validate(self, value)
	local x = ip.IPv4(value)
	return ( x and x:minhost()) and x:string() or ""
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
	tools.logger("wireless sharenet: "..sharenet)
	if (sharenet == "2") then
		--share internet was not enabled before, set to false now
		uci:set("freifunk","wizard","sharenet", 0)
		uci:save("freifunk")
	end

	-- store wizard data to fill fields if wizeard is rerun
	uci:set("freifunk", "wizard", "ssid", ssid:formvalue(section))
	uci:set("freifunk", "wizard", "dhcpmesh", dhcpmesh:formvalue(section))

	uci:foreach("wireless", "wifi-device",
		function(sec)
			local device = sec[".name"]

			-- store wizard data to fill fields if wizeard is rerun
			uci:set("freifunk", "wizard", "meship_" .. device, wifi_tbl[device]["meship"]:formvalue(section))

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
			util.update(devconfig, uci:get_all(external, "wifi_device") or {})
			devconfig.channel = getchannel(device)
			devconfig.hwmode = calchwmode(devconfig.channel, sec)
			devconfig.doth = calcdoth(devconfig.channel)
			devconfig.htmode = calchtmode(devconfig.channel)
			devconfig.country = calccountry(devconfig.channel)
			devconfig.chanlist = calcchanlist(devconfig.channel)
			uci:tset("wireless", device, devconfig)


			--WIRELESS CONFIG ad-hoc
			local ifconfig = uci:get_all("freifunk", "wifi_iface")
			util.update(ifconfig, uci:get_all(external, "wifi_iface") or {})
			ifconfig.device = device
			ifconfig.mcast_rate = ""
			ifconfig.network = calcnif(device)
			ifconfig.ifname = calcifcfg(device).."-".."adhoc".."-"..calcpre(devconfig.channel)
			ifconfig.mode = "adhoc"
			ifconfig.ssid = uci:get("profile_"..community,"ssidscheme",devconfig.channel)
			ifconfig.bssid = uci:get("profile_"..community,"bssidscheme",devconfig.channel)
			uci:section("wireless", "wifi-iface", nil, ifconfig)


			--NETWORK CONFIG ad-hoc
			local node_ip = wifi_tbl[device]["meship"]:formvalue(section)
			node_ip = ip.IPv4(node_ip)
			local prenetconfig = uci:get_all("freifunk", "interface") or {}
			util.update(prenetconfig, uci:get_all(external, "interface") or {})
			prenetconfig.proto = "static"
			prenetconfig.ipaddr = node_ip:host():string()
			if node_ip:prefix() < 32 then
				prenetconfig.netmask = node_ip:mask():string()
			end
			prenetconfig.ip6assign=64
			uci:section("network", "interface", calcnif(device), prenetconfig)


			--WIRELESS CONFIG ap
			uci:section("wireless", "wifi-iface", nil, {
				device=device,
				mode="ap",
				encryption ="none",
				network="dhcp",
				ifname=calcifcfg(device).."-dhcp-"..calcpre(devconfig.channel),
				ssid=ssid:formvalue(section)
			})

			--NETWORK CONFIG ap
			-- let's try to create a bridge after this loop

			uci:save("firewall")
			uci:save("olsrd")
			uci:save("olsrd6")
			uci:save("wireless")
			uci:save("network")

		end)


	local dhcpmeshnet = dhcpmesh:formvalue(section)
	dhcpmeshnet = ip.IPv4(dhcpmeshnet)

	--NETWORK CONFIG bridge for wifi APs
	uci:section("network", "interface", "dhcp", {
        	type="bridge",
        	proto="static",
       		ipaddr=dhcpmeshnet:minhost():string(),
        	netmask=dhcpmeshnet:mask():string(),
        	ip6assign="64"
	})

	--DHCP CONFIG bridge for wifi APs
	local dhcpbase = uci:get_all("freifunk", "dhcp") or {}
	util.update(dhcpbase, uci:get_all(external, "dhcp") or {})
	dhcpbase.interface = "dhcp"
	dhcpbase.force = 1
	dhcpbase.ignore = 0
	uci:section("dhcp", "dhcp", "dhcp", dhcpbase)
	uci:set_list("dhcp", "dhcp", "dhcp_option", "119,olsr")


	--OLSR CONFIG bridge interface
	uci:section("olsrd", "Hna4", nil, {
		netmask = dhcpmeshnet:mask():string(),
		netaddr = dhcpmeshnet:network():string()
	})
	uci:foreach("olsrd", "LoadPlugin",
		function(s)
			if s.library == "olsrd_p2pd.so.0.1.0" then
				uci:set("olsrd", s['.name'], "ignore", "1")
				local nonolsr = uci:get_list("olsrd", s['.name'], "NonOlsrIf") or {}
				table.insert(nonolsr,"dhcp")
				uci:set_list("olsrd", s['.name'], "NonOlsrIf", nonolsr)
			end
		end)

	uci:foreach("olsrd6", "LoadPlugin",
               	function(s)
                       	if s.library == "olsrd_p2pd.so.0.1.0" then
                               	uci:set("olsrd6", s['.name'], "ignore", "1")
                               	local nonolsr = uci:get_list("olsrd", s['.name'], "NonOlsrIf") or {}
                               	table.insert(nonolsr,"dhcp")
                               	uci:set_list("olsrd6", s['.name'], "NonOlsrIf", nonolsr)
                       	end
               	end)

	uci:save("dhcp")
	uci:save("olsrd")
	uci:save("olsrd6")
	uci:save("network")
	uci:save("freifunk")
end

function f.on_cancel()
        luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/decide"))
end


function f.handle(self, state, data)
        if state == FORM_VALID then
        	luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/applyChanges"))
        end
end

function calcpre(channel)
	local pre
	if channel > 0 and channel <= 14 then
		pre = 2
	elseif channel >= 36 and channel <= 64 or channel >= 100 and channel <= 140 then
		pre = 5
	end
	return pre
end


function calccountry(channel)
	local country
	if channel >= 100 and channel <= 140 then
		country = "DE"
	else
		country = "00"
	end
	return country
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
	local doth
	if channel >= 100 and channel <= 140 then
		doth = "1"
	else
		doth = "0"
	end
	return doth
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
	local hwmode

	if sec.type == "mac80211" then
		hwmode = sec.hwmode
		if hwmode and string.find(hwmode, "n") then
			has_n = "n"
		end
	end
	local hwmode = "11"..(has_n or "")
	if channel >0 and channel <=14 then
		hwmode = hwmode.."g"
	elseif channel >= 100 and channel <= 140 then
		hwmode = hwmode.."a"
	end
	return hwmode
end


function getchannel(device)
	local r_channel
	--TODO get channel from profile
	if device == "radio0" then
		r_channel=13
	end
	if device == "radio1" then
		r_channel = 36
	end
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
