--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>
Copyright 2011 Patrick Grimm <patrick@pberg.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id$

]]--


local uci = require "luci.model.uci".cursor()
local uci_state = require "luci.model.uci".cursor_state()
local tools = require "luci.tools.ffwizard"
local util = require "luci.util"
local sys = require "luci.sys"
local ip = require "luci.ip"
local fs  = require "nixio.fs"
local fs_luci = require "luci.fs"

local has_3g = fs.access("/lib/netifd/proto/3g.sh")
local has_pppoe = fs.glob("/usr/lib/pppd/*/rp-pppoe.so")()
local has_l2gvpn = fs.access("/usr/sbin/node")
local has_ovpn = fs.access("/usr/sbin/openvpn")
local has_firewall = fs.access("/etc/config/firewall")
local has_rom = fs.access("/rom/etc")
local has_diff = fs.access("/usr/bin/diff")
local has_6to4 = fs.access("/lib/netifd/proto/6to4.sh")
local has_6in4 = fs.access("/lib/netifd/proto/6in4.sh")
local has_auto_ipv6_node = fs.access("/etc/config/auto_ipv6_node")
local has_auto_ipv6_gw = fs.access("/etc/config/auto_ipv6_gw")
local has_qos = fs.access("/etc/init.d/qos")
local has_ipv6 = fs.access("/proc/sys/net/ipv6")
local has_6relayd = fs.access("/usr/sbin/6relayd")
local has_hostapd = fs.access("/usr/sbin/hostapd")
local has_wan = uci:get("network", "wan", "proto")
local has_lan = uci:get("network", "lan", "proto")
local has_pr = fs.access("/etc/config/freifunk-policyrouting")
local has_splash = fs.access("/usr/sbin/luci-splash")
local has_splash_enable
local profiles = "/etc/config/profile_"
local device_il = {
	"loopback",
	"6to4",
	"henet",
	"tun",
	"gvpn",
	"wifi",
	"wl",
	"wlan",
	"wireless",
	"radio",
	"eth",
	"dhcp",
	"ffvpn",
	"wan6"
}

if has_6in4 then
	if not uci:get("network", "henet") then
		uci:section("network", "interface", "henet", { proto="6in4"})
		uci:save("network")
	end
end

function logger(msg)
	sys.exec("logger -t ffwizard -p 5 '"..msg.."'")
end

local function txpower_list(iw)
	local list = iw.txpwrlist or { }
	local off  = tonumber(iw.txpower_offset) or 0
	local new  = { }
	local prev = -1
	local _, val
	for _, val in ipairs(list) do
		local dbm = val.dbm + off
		local mw  = math.floor(10 ^ (dbm / 10))
		if mw ~= prev then
			prev = mw
			new[#new+1] = {
				display_dbm = dbm,
				display_mw  = mw,
				driver_dbm  = val.dbm,
				driver_mw   = val.mw
			}
		end
	end
	return new
end

local function txpower_current(pwr, list)
	pwr = tonumber(pwr)
	if pwr ~= nil then
		local _, item
		for _, item in ipairs(list) do
			if item.driver_dbm >= pwr then
				return item.driver_dbm
			end
		end
	end
	return (list[#list] and list[#list].driver_dbm) or pwr or 0
end


-------------------- View --------------------
f = SimpleForm("ffwizward", "Freifunkassistent",
 "Dieser Assistent unterstützt Sie bei der Einrichtung des Routers für das Freifunknetz. Eine ausführliche Dokumentation ist auf http://wiki.freifunk.net/Freifunk_Berlin_Pberg:Firmware#FF_Wizard nach zu lesen")

local newpsswd = not has_rom or not has_diff or sys.exec("diff /rom/etc/shadow /etc/shadow")
if newpsswd ~= "" then
	pw = f:field(Flag, "pw", "Router Passwort", "Setzen Sie den Haken, um Ihr Passwort zu ändern.")
	function pw.cfgvalue(self, section)
		return 1
	end
end

pw1 = f:field(Value, "pw1", translate("Password"))
pw1.password = true
pw1.rmempty = false

pw2 = f:field(Value, "pw2", translate("Confirmation"))
pw2.password = true
pw2.rmempty = false

function pw2.validate(self, value, section)
	return pw1:formvalue(section) == value and value
end

if newpsswd ~= "" then
	pw1:depends("pw", "1")
	pw2:depends("pw", "1")
end

net = f:field(ListValue, "net", "Freifunk Community", "Nutzen Sie die Einstellungen der Freifunk Gemeinschaft in ihrer Nachbarschaft.")
net.rmempty = false
net.optional = false
net.datatype = "string"

local list = {}
local list = fs_luci.glob(profiles .. "*")

function net.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "net") or "berlin"
end
function net.write(self, section, value)
	uci:set("freifunk", "wizard", "net", value)
	uci:save("freifunk")
end
net_lat = f:field(ListValue, "net_lat", "", "")
net_lat:depends("net", "0")
net_lat.datatype = "float"
net_lon = f:field(ListValue, "net_lon", "", "")
net_lon:depends("net", "0")
net_lon.datatype = "float"

for k,v in ipairs(list) do
	local n = string.gsub(v, profiles, "")
	local name = uci:get_first("profile_"..n, "community", "name") or "?"
	net:value(n, name)
	local latitude = uci:get_first("profile_"..n, "community", "latitude") or "?"
	local longitude = uci:get_first("profile_"..n, "community", "longitude") or "?"
	net_lat:value(n, "%s" % {latitude or "?"})
	net_lon:value(n, "%s" % {longitude or "?"})
end

-- hostname
hostname = f:field(Value, "hostname", "Knoten Name", "Geben Sie Ihrem Freifunk Router einen Namen. Wenn Sie dieses Feld leer lassen, wird der Name automatisch aus der Mesh IP generiert.")
hostname.rmempty = true
hostname.optional = false
hostname.datatype = "hostname"
function hostname.cfgvalue(self, section)
	return sys.hostname()
end
function hostname.write(self, section, value)
	uci:set("freifunk", "wizard", "hostname", value)
	uci:save("freifunk")
end

-- location
local loc=uci:get_first("system", "system", "location") or uci:get("freifunk", "contact", "location")
location = f:field(Value, "location", "Standort", "Geben Sie den Standort ihres Gerätes an")
location.rmempty = false
location.optional = false
location.datatype = "string"
function location.cfgvalue(self, section)
	return loc
end

-- mail
mail = f:field(Value, "mail", "E-Mail", "Bitte hinterlegen Sie eine Kontaktadresse.")
mail.rmempty = false
mail.optional = false
mail.datatype = "string"
function mail.cfgvalue(self, section)
	return uci:get("freifunk", "contact", "mail")
end
function mail.write(self, section, value)
	uci:set("freifunk", "contact", "mail", value)
	uci:save("freifunk")
end
-- main freifunk netconfig
main = f:field(DummyValue, "netconfig", "<b>Freifunk Netzwerk einrichten Anfang</b>", "====================================================================")
main.forcewrite = true
function main.parse(self, section)
	local fvalue = "1"
	if self.forcewrite then
		self:write(section, fvalue)
	end
end
local wifi_tbl = {}
uci:foreach("wireless", "wifi-device",
	function(section)
		local device = section[".name"]
		local hwtype = section.type
		wifi_tbl[device] = {}
		local dev = f:field(Flag, "device_" .. device , "<b>Drahtloses Freifunk Netzwerk \"" .. device:upper() .. "\"</b> ", "Konfigurieren Sie Ihre drahtlose Schnittstelle: " .. device:upper() .. ".")
			dev.rmempty = false
			dev.forcewrite = true
			function dev.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "device_" .. device)
			end
			function dev.write(self, sec, value)
				if value then
					uci:set("freifunk", "wizard", "device_" .. device, value)
					uci:save("freifunk")
				end
			end
			wifi_tbl[device]["dev"] = dev
		local iw = luci.sys.wifi.getiwinfo(device)
		local tx_power_list = txpower_list(iw)
		local tx_power_cur  = txpower_current(section.txpower, tx_power_list)
		local chan = f:field(ListValue, "chan_" .. device, device:upper() .. "  Freifunk Kanal einrichten", "Ihr Gerät und benachbarte Freifunk Knoten müssen auf demselben Kanal senden. Je nach Gerätetyp können Sie zwischen verschiedenen 2,4Ghz und 5Ghz Kanälen auswählen.")
			chan:depends("device_" .. device, "1")
			chan:depends("dhcpbr_" .. device, "1")
			chan.rmempty = true
			function chan.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "chan_" .. device)
			end
			chan:value('default')
			for _, f in ipairs(iw and iw.freqlist or { }) do
				if not f.restricted then
					chan:value(f.channel, "%i (%.3f GHz)" %{ f.channel, f.mhz / 1000 })
				else
					chan:value(f.channel, "%i (%.3f GHz restricted DFS)" %{ f.channel, f.mhz / 1000 })
				end
			end
			function chan.write(self, sec, value)
				if value then
					uci:set("freifunk", "wizard", "chan_" .. device, value)
					uci:save("freifunk")
				end
			end
			wifi_tbl[device]["chan"] = chan
		local advanced = f:field(Flag, "advanced_" .. device, device:upper() .. " Erweiterte WLAN Einstellungen", "advanced")
			advanced:depends("device_" .. device, "1")
			advanced:depends("dhcpbr_" .. device, "1")
			advanced.rmempty = false
			function advanced.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "advanced_" .. device)
			end
			function advanced.write(self, sec, value)
				uci:set("freifunk", "wizard", "advanced_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["advanced"] = advanced
		local hwmode = f:field(ListValue, "hwmode_" .. device, device:upper() .. "  "..translate("Mode"))
			hwmode:depends("advanced_" .. device, "1")
			hwmode.rmempty = true
			hwmode.widget = "radio"
			hwmode.orientation = "horizontal"
			local hw_modes = iw.hwmodelist or { }
			if hw_modes.b then hwmode:value("11b", "802.11b") end
			if hw_modes.g then hwmode:value("11g", "802.11g") end
			if hw_modes.a then hwmode:value("11a", "802.11a") end
			if hw_modes.b and hw_modes.g then hwmode:value("11bg", "802.11b + g") end
			if hw_modes.g and hw_modes.n then hwmode:value("11ng", "802.11n + g") end
			if hw_modes.a and hw_modes.n then hwmode:value("11na", "802.11n + a") end
			function hwmode.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "hwmode_" .. device)
			end
			function hwmode.write(self, sec, value)
				uci:set("freifunk", "wizard", "hwmode_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["hwmode"] = hwmode
		local htmode = f:field(ListValue, "htmode_" .. device, device:upper() .. "  "..translate("HT mode"))
			htmode:depends("hwmode_" .. device, "11na")
			htmode:depends("hwmode_" .. device, "11ng")
			htmode.rmempty = true
			htmode.widget = "radio"
			htmode.orientation = "horizontal"
			htmode:value("HT20", "20MHz")
			htmode:value("HT40-", translate("40MHz 2nd channel above"))
			htmode:value("HT40+", translate("40MHz 2nd channel below"))
			function htmode.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "htmode_" .. device)
			end
			function htmode.write(self, sec, value)
				uci:set("freifunk", "wizard", "htmode_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["htmode"] = htmode
		local txpower = f:field(ListValue, "txpower_" .. device, device:upper().."  "..translate("Transmit Power"), "dBm")
			txpower:depends("advanced_" .. device, "1")
			txpower.rmempty = true
			txpower.default = 15
			function txpower.cfgvalue(...)
				return uci:get("freifunk", "wizard", "txpower_" .. device)
			end
			for _, p in ipairs(tx_power_list) do
				txpower:value(p.driver_dbm, "%i dBm (%i mW)"
					%{ p.display_dbm, p.display_mw })
			end
			function txpower.write(self, sec, value)
				uci:set("freifunk", "wizard", "txpower_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["txpower"] = txpower
		local distance = f:field(Value, "distance_" .. device, device:upper().."  "..translate("Distance Optimization"), translate("Distance to farthest network member in meters."))
			distance:depends("advanced_" .. device, "1")
			distance.rmempty = true
			distance.datatype = "range(0,10000)"
			function distance.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "distance_" .. device)
			end
			function distance.write(self, sec, value)
				uci:set("freifunk", "wizard", "distance_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["distance"] = distance
		local txantenna = f:field(ListValue, "txantenna_" .. device, device:upper() .."  ".. translate("Transmitter Antenna"))
			txantenna:depends("advanced_" .. device, "1")
			txantenna.rmempty = true
			txantenna.widget = "radio"
			txantenna.orientation = "horizontal"
			txantenna:value("all", translate("all"))
			txantenna:value("1", translate("Antenna 1"))
			txantenna:value("2", translate("Antenna 2"))
			txantenna:value("4", translate("Antenna 3"))
			function txantenna.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "txantenna_" .. device)
			end
			function txantenna.write(self, sec, value)
				uci:set("freifunk", "wizard", "txantenna_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["txantenna"] = txantenna
		local rxantenna = f:field(ListValue, "rxantenna_" .. device, device:upper().."  "..translate("Receiver Antenna"))
			rxantenna:depends("advanced_" .. device, "1")
			rxantenna.rmempty = true
			rxantenna.widget = "radio"
			rxantenna.orientation = "horizontal"
			if hwtype == "atheros" then
				rxantenna:value("0", translate("auto"))
				rxantenna:value("1", translate("Antenna 1"))
				rxantenna:value("2", translate("Antenna 2"))
			end
			if hwtype == "broadcom" then
				rxantenna:value("3", translate("auto"))
				rxantenna:value("0", translate("Antenna 1"))
				rxantenna:value("1", translate("Antenna 2"))
			end
			if hwtype == "mac80211" then
				rxantenna:value("all", translate("all"))
				rxantenna:value("1", translate("Antenna 1"))
				rxantenna:value("2", translate("Antenna 2"))
				rxantenna:value("4", translate("Antenna 3"))
			end
			function rxantenna.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "rxantenna_" .. device)
			end
			function rxantenna.write(self, sec, value)
				uci:set("freifunk", "wizard", "rxantenna_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["rxantenna"] = rxantenna
		local meship = f:field(Value, "meship_" .. device, device:upper() .. "  Mesh IP Adresse einrichten", "Ihre Mesh IP Adresse erhalten Sie von der Freifunk Gemeinschaft in Ihrer Nachbarschaft. Es ist eine netzweit eindeutige Identifikation, z.B. 104.1.1.1.")
			meship:depends("device_" .. device, "1")
			meship.rmempty = true
			meship.datatype = "ip4addr"
			function meship.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "meship_" .. device)
			end
			function meship.validate(self, value)
				local x = ip.IPv4(value)
				return ( x and x:is4()) and x:string() or ""
			end
			function meship.write(self, sec, value)
				uci:set("freifunk", "wizard", "meship_" .. device, value)
				local new_ip = ip.IPv4(value)
				if new_ip then
					local new_hostname = new_ip:string():gsub("%.", "-")
					uci:set("freifunk", "wizard", "hostname", new_hostname)
					uci:save("freifunk")
				end
			end
			wifi_tbl[device]["meship"] = meship
		local client = f:field(Flag, "client_" .. device, device:upper() .. "  DHCP anbieten", "DHCP weist verbundenen Benutzern automatisch eine Adresse zu. Diese Option sollten Sie unbedingt aktivieren, wenn Sie Nutzer an der drahtlosen Schnittstelle erwarten.")
			client:depends("device_" .. device, "1")
			client.rmempty = false
			function client.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "client_" .. device)
			end
			function client.write(self, sec, value)
				uci:set("freifunk", "wizard", "client_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["client"] = client
		local dhcpmesh = f:field(Value, "dhcpmesh_" .. device, device:upper() .. "  Mesh DHCP anbieten", "Bestimmen Sie den Adressbereich aus dem Ihre Nutzer IP Adressen erhalten. Es wird empfohlen einen Adressbereich aus Ihrer lokalen Freifunk Gemeinschaft zu nutzen. Der Adressbereich ist ein netzweit eindeutiger Netzbereich. z.B. 104.1.2.1/28 Wenn das Feld leer bleibt wird ein Netzwerk automatisch nach den vorgaben aus dem Feld Freifunk Comunity erstellt")
			dhcpmesh:depends("client_" .. device, "1")
			dhcpmesh.rmempty = true
			dhcpmesh.datatype = "ip4addr"
			function dhcpmesh.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "dhcpmesh_" .. device)
			end
			function dhcpmesh.validate(self, value)
				local x = ip.IPv4(value)
				return ( x and x:minhost()) and x:string() or ""
			end
			function dhcpmesh.write(self, sec, value)
				uci:set("freifunk", "wizard", "dhcpmesh_" .. device, value)
				uci:save("freifunk")
			end
			wifi_tbl[device]["dhcpmesh"] = dhcpmesh
		if has_splash then
			local dhcpsplash = f:field(Flag, "dhcpsplash_" .. device, device:upper() .. "  DHCP Splash Seite", "Soll eine Splash Seite angezeigt werden?")
				dhcpsplash:depends("client_" .. device, "1")
				dhcpsplash.rmempty = true
				function dhcpsplash.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "dhcpsplash_" .. device)
				end
				function dhcpsplash.write(self, sec, value)
					uci:set("freifunk", "wizard", "dhcpsplash_" .. device, value)
					uci:save("freifunk")
				end
				wifi_tbl[device]["dhcpsplash"] = dhcpsplash
		end
		if hwtype == "mac80211" and has_hostapd then
			local vap = f:field(Flag, "vap_" .. device , "Virtueller Drahtloser Zugangspunkt", "Konfigurieren Sie Ihren Virtuellen AP")
				vap:depends("client_" .. device, "1")
				vap.rmempty = false
				function vap.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "vap_" .. device) or "1"
				end
				function vap.write(self, sec, value)
					uci:set("freifunk", "wizard", "vap_" .. device, value)
					uci:save("freifunk")
				end
				wifi_tbl[device]["vap"] = vap
			local vapssid = f:field(Value, "vapssid_" .. device , "SSID des Virtuellen Drahtlosen Zugangspunktes", "Name des Virtuellen AP oder nichts fuer AP+Kanal+SSID der Freifunk Community")
				vapssid:depends("vap_" .. device, "1")
				vapssid:depends("dhcpbr_" .. device, "1")
				vapssid.rmempty = true
				function vapssid.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "vapssid_" .. device)
				end
				wifi_tbl[device]["vapssid"] = vapssid
			local dhcpbr = f:field(Flag, "dhcpbr_" .. device, device:upper() .. "  Mesh DHCP Bruecke", "Soll der Virtuellen AP auf das LAN OLSR dhcp Netz gebrueckt werden")
				dhcpbr:depends("device_lan", "1")
				dhcpbr.rmempty = false
				function dhcpbr.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "dhcpbr_" .. device) or "0"
				end
				function dhcpbr.write(self, sec, value)
					uci:set("freifunk", "wizard", "dhcpbr_" .. device, value)
					uci:save("freifunk")
				end
				wifi_tbl[device]["dhcpbr"] = dhcpbr
		end
	end)

local wired_tbl = {}
uci:foreach("network", "interface",
	function(section)
		local device_i
		local device = section[".name"]
		local ifname = uci_state:get("network",device,"ifname")
		for i, v in ipairs(device_il) do
			if string.find(device, v) then
				device_i = true
			end
		end
		if device_i then
			logger("ignore: "..device)
			return
		end
		wired_tbl[device] = {}
		local dev = f:field(Flag, "device_" .. device , "<b>Drahtgebundenes Freifunk Netzwerk \"" .. device:upper() .. "\"</b>", "Konfigurieren Sie Ihre drahtgebunde Schnittstelle: " .. device:upper() .. ".")
			dev.rmempty = false
			function dev.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "device_" .. device)
			end
			function dev.write(self, sec, value)
				uci:set("freifunk", "wizard", "device_" .. device, value)
				uci:save("freifunk")
			end
			wired_tbl[device]["dev"] = dev
		local meship = f:field(Value, "meship_" .. device, device:upper() .. "  Mesh IP Adresse einrichten", "Ihre Mesh IP Adresse erhalten Sie von der Freifunk Gemeinschaft in Ihrer Nachbarschaft. Es ist eine netzweit eindeutige Identifikation, z.B. 104.1.1.1.")
			meship:depends("device_" .. device, "1")
			meship.rmempty = true
			meship.datatype = "ip4addr"
			function meship.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "meship_" .. device)
			end
			function meship.validate(self, value)
				local x = ip.IPv4(value)
				return ( x and x:is4()) and x:string() or ""
			end
			function meship.write(self, sec, value)
				uci:set("freifunk", "wizard", "meship_" .. device, value)
			end
			wired_tbl[device]["meship"] = meship
		local client = f:field(Flag, "client_" .. device, device:upper() .. "  DHCP anbieten","DHCP weist verbundenen Benutzern automatisch eine Adresse zu. Diese Option sollten Sie unbedingt aktivieren, wenn Sie Nutzer an der drahtlosen Schnittstelle erwarten.")
			client:depends("device_" .. device, "1")
			client.rmempty = false
			function client.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "client_" .. device)
			end
			function client.write(self, sec, value)
				uci:set("freifunk", "wizard", "client_" .. device, value)
				uci:save("freifunk")
			end
			wired_tbl[device]["client"] = client
		local dhcpmesh = f:field(Value, "dhcpmesh_" .. device, device:upper() .. "  Mesh DHCP anbieten ", "Bestimmen Sie den Adressbereich aus dem Ihre Nutzer IP Adressen erhalten. Es wird empfohlen einen Adressbereich aus Ihrer lokalen Freifunk Gemeinschaft zu nutzen. Der Adressbereich ist ein netzweit eindeutiger Netzbereich. z.B. 104.1.2.1/28")
			dhcpmesh:depends("client_" .. device, "1")
			dhcpmesh.rmempty = true
			dhcpmesh.datatype = "ip4addr"
			function dhcpmesh.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "dhcpmesh_" .. device)
			end
			function dhcpmesh.validate(self, value)
				local x = ip.IPv4(value)
				return ( x and x:prefix() <= 30 and x:minhost()) and x:string() or ""
			end
			function dhcpmesh.write(self, sec, value)
				uci:set("freifunk", "wizard", "dhcpmesh_" .. device, value)
				uci:save("freifunk")
			end
			wired_tbl[device]["dhcpmesh"] = dhcpmesh
		if has_splash then
			local dhcpsplash = f:field(Flag, "dhcpsplash_" .. device, device:upper() .. "  DHCP Splash Seite", "Soll eine Splash Seite angezeigt werden?")
				dhcpsplash:depends("client_" .. device, "1")
				dhcpsplash.rmempty = true
				function dhcpsplash.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "dhcpsplash_" .. device)
				end
				function dhcpsplash.write(self, sec, value)
					uci:set("freifunk", "wizard", "dhcpsplash_" .. device, value)
					uci:save("freifunk")
				end
			wired_tbl[device]["dhcpsplash"] = dhcpsplash
		end
	end)


local syslat
local syslon
uci:foreach("system", "system", function(s)
		if s.latitude and s.longitude then
			syslat = s.latitude
			syslon = s.longitude
		end
end)

if not syslat or not syslon then
	f:field(DummyValue, "unset_latlon", "<b>Achtung Längengrad und Breitengrad nicht gesetzt</b>", "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV")
	syslat = 52
	syslon = 10
end

local lat = f:field(Value, "lat", "geographischer Breitengrad", "Setzen Sie den Breitengrad (Latitude) Ihres Geräts.")
lat.datatype = "float"
function lat.cfgvalue(self, section)
	return syslat
end

local lon = f:field(Value, "lon", "geograpischer Längengrad", "Setzen Sie den Längengrad (Longitude) Ihres Geräts.")
lon.datatype = "float"
function lon.cfgvalue(self, section)
	return syslon
end

--[[
*Opens an OpenStreetMap iframe or popup
*Makes use of resources/OSMLatLon.htm and htdocs/resources/osm.js
(is that the right place for files like these?)
]]--

local class = util.class

OpenStreetMapLonLat = class(AbstractValue)

function OpenStreetMapLonLat.__init__(self, ...)
	AbstractValue.__init__(self, ...)
	self.template = "cbi/osmll_value_pberg"
	self.latfield = nil
	self.lonfield = nil
	self.centerlat = ""
	self.centerlon = ""
	self.zoom = "0"
	self.width = "100%" --popups will ignore the %-symbol, "100%" is interpreted as "100"
	self.height = "600"
	self.popup = false
	self.displaytext="OpenStreetMap" --text on button, that loads and displays the OSMap
	self.hidetext="X" -- text on button, that hides OSMap
end

local osm = f:field(OpenStreetMapLonLat, "latlon", "Geokoordinaten mit OpenStreetMap ermitteln:", "Klicken Sie auf Ihren Standort in der Karte. Diese Karte funktioniert nur, wenn das Gerät bereits eine Verbindung zum Internet hat.")
osm.latfield = "lat"
osm.lonfield = "lon"
osm.centerlat = syslat
osm.centerlon = syslon
osm.width = "100%"
osm.height = "600"
osm.popup = false
syslatlengh = string.len(syslat)
if syslatlengh > 7 then
	osm.zoom = "15"
elseif syslatlengh > 5 then
	osm.zoom = "12"
else
	osm.zoom = "6"
end
osm.displaytext="OpenStreetMap anzeigen"
osm.hidetext="OpenStreetMap verbergen"

f:field(DummyValue, "dummynetconfig", "<b>Freifunk Netzwerk einrichten Ende</b>", "====================================================================")

if has_wan then
	local fwanipn
	local fwanip
	local fwannm
	local fwangw
	local fwandns = ""
	local wanetm = require "luci.model.network".init()
	local wanet_uci = wanetm:get_network("wan")
	if wanet_uci and #wanet_uci > 0 then
		fwanip = wanet_uci:ipaddr()
		fwannm = wanet_uci:netmask()
		fwangw = wanet_uci:gwaddr()
		for _,v in ipairs(wanet_uci:dnsaddrs()) do
			fwandns = fwandns.." "..v
		end
		fwanipn = ip.IPv4(fwanip,fwannm)
	end
	wanproto = f:field(ListValue, "wanproto", "<b>Internet WAN </b>", " Geben Sie das Protokol an ueber das eine Internet verbindung hergestellt werden kann.")
	if fwanipn and fwanipn:string() and fwangw and fwandns then
		f:field(DummyValue, "wanprotod", "IP:", fwanipn:string().." Gateway: "..fwangw.." DNS: "..fwandns)
	end
	wanproto:depends("device_wan", "")
	wanproto:value("static", translate("manual", "manual"))
	wanproto:value("dhcp", translate("automatic", "automatic"))
	if has_pppoe then wanproto:value("pppoe", "PPPoE") end
	if has_3g    then wanproto:value("3g",    "UMTS/3G") end
	function wanproto.cfgvalue(self, section)
		return uci:get("network", "wan", "proto") or "dhcp"
	end
	function wanproto.write(self, section, value)
		uci:set("network", "wan", "proto", value)
		uci:set("network", "wan", "peerdns", "0")
		if value == "3g" or value == "pppoe" then
			uci:set("network", "wan", "defaultroute", "1")
		end
		uci:save("network")
	end

	sharenet = f:field(Flag, "sharenet", "Eigenen Internetzugang freigeben", "Geben Sie Ihren Internetzugang im Freifunknetz frei.")
	sharenet.rmempty = false
	sharenet.optional = false
	sharenet:depends("device_wan", "")
	function sharenet.cfgvalue(self, section)
		return uci:get("freifunk", "wizard", "sharenet")
	end
	function sharenet.write(self, section, value)
		uci:set("freifunk", "wizard", "sharenet", value)
		uci:save("freifunk")
	end

	wanipaddr = f:field(Value, "wanipaddr", translate("IPv4-Address"))
	wanipaddr:depends("wanproto", "static")
	wanipaddr.datatype = "ip4addr"
	function wanipaddr.cfgvalue(self, section)
		return uci:get("network", "wan", "ipaddr")
	end
	function wanipaddr.write(self, section, value)
		uci:set("network", "wan", "ipaddr", value)
		uci:save("network")
	end

	wannetmask = f:field(Value, "wannetmask", translate("IPv4-Netmask"))
	wannetmask:depends("wanproto", "static")
	wannetmask.datatype = "ip4addr"
	wannetmask:value("255.255.255.0")
	wannetmask:value("255.255.0.0")
	wannetmask:value("255.0.0.0")
	function wannetmask.cfgvalue(self, section)
		return uci:get("network", "wan", "netmask")
	end
	function wannetmask.write(self, section, value)
		uci:set("network", "wan", "netmask", value)
		uci:save("network")
	end

	wangateway = f:field(Value, "wangateway", translate("IPv4-Gateway"))
	wangateway:depends("wanproto", "static")
	wangateway.datatype = "ip4addr"
	function wangateway.cfgvalue(self, section)
		return uci:get("network", "wan", "gateway")
	end
	function wangateway.write(self, section, value)
		uci:set("network", "wan", "gateway", value)
		uci:save("network")
	end
	function wangateway.remove(self, section)
		uci:delete("network", "wan", "gateway")
		uci:save("network")
	end

	wandns = f:field(Value, "wandns", translate("DNS-Server"), "Bitte *nicht* die IP Adresse des Internetrouters eintragen. Nur Public DNS Server. z.B. 8.8.8.8 google, 141.54.1.1 UNI Weimar, ...")
	wandns:depends("wanproto", "static")
	wandns.cast = "string"
	wandns.datatype = "ipaddr"
	function wandns.cfgvalue(self, section)
		return uci:get("network", "wan", "dns")
	end
	function wandns.write(self, section, value)
		uci:set("network", "wan", "dns", value)
		uci:save("network")
	end

	wanusername = f:field(Value, "wanusername", translate("Username"))
	wanusername:depends("wanproto", "pppoe")
	wanusername:depends("wanproto", "3g")
	wanusername.rmempty = true
	function wanusername.cfgvalue(self, section)
		return uci:get("network", "wan", "username")
	end
	function wanusername.write(self, section, value)
		uci:set("network", "wan", "username", value)
		uci:save("network")
	end

	wanpassword = f:field(Value, "wanpassword", translate("Password"))
	wanpassword.password = true
	wanpassword:depends("wanproto", "pppoe")
	wanpassword:depends("wanproto", "3g")
	wanpassword.rmempty = true
	function wanpassword.cfgvalue(self, section)
		return uci:get("network", "wan", "password")
	end
	function wanpassword.write(self, section, value)
		uci:set("network", "wan", "password", value)
		uci:save("network")
	end
	if has_firewall then
		wansec = f:field(Flag, "wansec", "WAN-Zugriff auf Gateway beschränken", "Verbieten Sie Zugriffe auf Ihr lokales Netzwerk aus dem Freifunknetz.")
		wansec.rmempty = false
		wansec:depends("sharenet", "1")
		function wansec.cfgvalue(self, section)
			return uci:get("freifunk", "wizard", "wan_security") or "1"
		end
		function wansec.write(self, section, value)
			uci:set("freifunk", "wizard", "wan_security", value)
			uci:save("freifunk")
		end
		--wanopenfw open wan input fw
		wanopenfw = f:field(Flag, "wanopenfw", "Zugriff vom WAN auf das Geraet erlauben", "Wenn der WAN Port mit Ihrem lokalen Netzwerk verbunden ist.")
		wanopenfw.rmempty = false
		wanopenfw:depends("sharenet", "1")
		function wanopenfw.cfgvalue(self, section)
			return uci:get("freifunk", "wizard", "wan_input_accept") or "1"
		end
		function wanopenfw.write(self, section, value)
			uci:set("freifunk", "wizard", "wan_input_accept", value)
			uci:save("freifunk")
		end
	end
	wandevice = f:field(Value, "wandevice",
		translate("Network or Modem device"),
		translate("The device node of your modem, e.g. /dev/ttyUSB0 or eth0.2")
	)
	if has_3g then
		wandevice:value("/dev/ttyUSB0")
	end
	wandevice:depends("wanproto", "dhcp")
	wandevice:depends("wanproto", "static")
	wandevice:depends("wanproto", "3g")
	function wandevice.cfgvalue(self, section)
		return uci:get("network", "wan", "device")
	end
	function wandevice.write(self, section, value)
		uci:set("network", "wan", "device", value)
		uci:save("network")
	end
	if has_3g then
		wanservice = f:field(ListValue, "wanservice", translate("Service type"))
		wanservice:value("", translate("-- Please choose --"))
		wanservice:value("umts", "UMTS/GPRS")
		wanservice:value("cdma", "CDMA")
		wanservice:value("evdo", "EV-DO")
		wanservice:depends("wanproto", "3g")
		wanservice.rmempty = true
		function wanservice.cfgvalue(self, section)
			return uci:get("network", "wan", "service")
		end
		function wanservice.write(self, section, value)
			uci:set("network", "wan", "service", value)
			uci:save("network")
		end

		wanapn = f:field(Value, "wanapn", translate("Access point (APN)"))
		wanapn:depends("wanproto", "3g")
		function wanapn.cfgvalue(self, section)
			return uci:get("network", "wan", "apn")
		end
		function wanapn.write(self, section, value)
			uci:set("network", "wan", "apn", value)
			uci:save("network")
		end

		wanpincode = f:field(Value, "wanpincode",
		translate("PIN code"),
		translate("Make sure that you provide the correct pin code here or you might lock your sim card!")
		)
		wanpincode.password = true
		wanpincode:depends("wanproto", "3g")
		function wanpincode.cfgvalue(self, section)
			return uci:get("network", "wan", "pincode")
		end
		function wanpincode.write(self, section, value)
			uci:set("network", "wan", "pincode", value)
			uci:save("network")
		end
	end

	if has_qos then
		wanqosdown = f:field(Value, "wanqosdown", "Download Bandbreite begrenzen", "kb/s")
		wanqosdown:depends("sharenet", "1")
		wanqosdown:value("1000","1 MBit/s")
		wanqosdown:value("10000","10 MBit/s")
		wanqosdown:value("100000","100 MBit/s")
		function wanqosdown.cfgvalue(self, section)
			return uci:get("qos", "wan", "download")
		end
		function wanqosdown.write(self, section, value)
			uci:set("qos", "wan", "download", value)
			uci:save("qos")
		end
		function wanqosdown.remove(self, section)
			uci:delete("qos", "wan", "download")
			uci:save("qos")
		end
		wanqosup = f:field(Value, "wanqosup", "Upload Bandbreite begrenzen", "kb/s")
		wanqosup:depends("sharenet", "1")
		wanqosup:value("1000","1 MBit/s")
		wanqosup:value("10000","10 MBit/s")
		wanqosup:value("100000","100 MBit/s")
		function wanqosup.cfgvalue(self, section)
			return uci:get("qos", "wan", "upload")
		end
		function wanqosup.write(self, section, value)
			uci:set("qos", "wan", "upload", value)
			uci:save("qos")
		end
		function wanqosup.remove(self, section)
			uci:delete("qos", "wan", "upload")
			uci:save("qos")
		end
	end
	if has_6in4 then
		henet = f:field(Flag, "henet", "Henet Tunnel", "Geben Sie Ihre Henet Tunnel daten ein.")
		henet.rmempty = false
		henet.optional = false
		henet:depends("device_wan", "")
		function henet.cfgvalue(self, section)
			return uci:get("freifunk", "wizard", "henet")
		end
		function henet.write(self, section, value)
			uci:set("freifunk", "wizard", "henet", value)
			uci:save("freifunk")
		end
		henetproto = f:field(Value, "henetproto", translate("Protokoll set 6in4"))
		henetproto:depends("henet", "1")
		henetproto.value = "6in4"
		function henetproto.write(self, section, value)
			uci:set("network", "henet", "proto", value)
			uci:save("network")
		end
		henetid = f:field(Value, "tunnelid", translate("Tunnel Id"))
		henetid:depends("henetproto", "6in4")
		henetid.rmempty = true
		function henetid.cfgvalue(self, section)
			return uci:get("network", "henet", "tunnelid")
		end
		function henetid.write(self, section, value)
			uci:set("network", "henet", "tunnelid", value)
			uci:save("network")
		end
		henetusr = f:field(Value, "henetusername", translate("Username"))
		henetusr:depends("henetproto", "6in4")
		henetusr.rmempty = true
		function henetusr.cfgvalue(self, section)
			return uci:get("network", "henet", "username")
		end
		function henetusr.write(self, section, value)
			uci:set("network", "henet", "username", value)
			uci:save("network")
		end
		henetpwd = f:field(Value, "henetpassword", translate("Password"))
		henetpwd.password = true
		henetpwd:depends("henetproto", "6in4")
		henetpwd.rmempty = true
		function henetpwd.cfgvalue(self, section)
			return uci:get("network", "henet", "password")
		end
		function henetpwd.write(self, section, value)
			uci:set("network", "henet", "password", value)
			uci:save("network")
		end
		henetip6addr = f:field(Value, "henetip6addr", translate("IPv6-Address"))
		henetip6addr:depends("henet", "1")
		henetip6addr.datatype = "ip6addr"
		function henetip6addr.cfgvalue(self, section)
			return uci:get("network", "henet", "ip6addr")
		end
		function henetip6addr.write(self, section, value)
			uci:set("network", "henet", "ip6addr", value)
			uci:save("network")
		end
		henetpeer = f:field(Value, "henetpeer", translate("Peer-Address"))
		henetpeer:depends("henet", "1")
		henetpeer.datatype = "ip4addr"
		function henetpeer.cfgvalue(self, section)
			return uci:get("network", "henet", "peeraddr")
		end
		function henetpeer.write(self, section, value)
			uci:set("network", "henet", "peeraddr", value)
			uci:save("network")
		end
		henetprefix = f:field(Value, "henetprefix", translate("IPv6 delegated Prefix"))
		henetprefix:depends("henet", "1")
		henetprefix.datatype = "ip6addr"
		function henetprefix.cfgvalue(self, section)
			return uci:get("network", "henet", "ip6prefix")
		end
		function henetprefix.write(self, section, value)
			uci:set("network", "henet", "ip6prefix", value)
			uci:save("network")
		end
	end
end

if has_lan then
	lanproto = f:field(ListValue, "lanproto", "<b>Lokales Netzwerk LAN</b>", "Geben Sie das Protokol der LAN Schnittstelle an.")
	lanproto:depends("device_lan", "")
	lanproto:value("static", translate("manual", "manual"))
	lanproto:value("dhcp", translate("automatic", "automatic"))
	function lanproto.cfgvalue(self, section)
		return uci:get("network", "lan", "proto") or "dhcp"
	end
	function lanproto.write(self, section, value)
		uci:set("network", "lan", "proto", value)
		uci:save("network")
	end
	lanipaddr = f:field(Value, "lanipaddr", translate("IPv4-Address"))
	lanipaddr:depends("lanproto", "static")
	function lanipaddr.cfgvalue(self, section)
		return uci:get("network", "lan", "ipaddr")
	end
	function lanipaddr.write(self, section, value)
		uci:set("network", "lan", "ipaddr", value)
		uci:save("network")
	end
	lannetmask = f:field(Value, "lannetmask", translate("IPv4-Netmask"))
	lannetmask:depends("lanproto", "static")
	function lannetmask.cfgvalue(self, section)
		return uci:get("network", "lan", "netmask")
	end
	function lannetmask.write(self, section, value)
		uci:set("network", "lan", "netmask", value)
		uci:save("network")
	end
	langateway = f:field(Value, "langateway", translate("IPv4-Gateway"))
	langateway:depends("lanproto", "static")
	langateway.rmempty = true
	function langateway.cfgvalue(self, section)
		return uci:get("network", "lan", "gateway")
	end
	function langateway.write(self, section, value)
		uci:set("network", "lan", "gateway", value)
		uci:save("network")
	end
	function langateway.remove(self, section)
		uci:delete("network", "lan", "gateway")
		uci:save("network")
	end
	langip6assign = f:field(Value, "langip6assign", translate("IPv6-Assign"))
	langip6assign:depends("lanproto", "static")
	langip6assign.rmempty = true
	function langip6assign.cfgvalue(self, section)
		return uci:get("network", "lan", "ip6assign") or 64
	end
	function langip6assign.write(self, section, value)
		uci:set("network", "lan", "ip6assign", value)
		uci:save("network")
	end
	landns = f:field(Value, "landns", translate("DNS-Server"))
	landns:depends("lanproto", "static")
	landns.rmempty = true
	function landns.cfgvalue(self, section)
		return ""
	end
	function landns.write(self, section, value)
		uci:set("network", "lan", "dns", value)
		uci:save("network")
	end
end

if has_ovpn then
	ffvpn = f:field(Flag, "ffvpn", "Freifunk Internet Tunnel", "Verbinden Sie ihren Router mit mit dem Frefunk VPN Sever 03.")
	ffvpn.rmempty = false
	ffvpn:depends("sharenet", "1")
	function ffvpn.cfgvalue(self, section)
		return uci:get("openvpn", "ffvpn", "enabled")
	end
	function ffvpn.write(self, section, value)
		uci:set("openvpn", "ffvpn", "enabled", value)
		uci:save("openvpn")
	end
end

if has_l2gvpn then
	gvpn = f:field(Flag, "gvpn", "Freifunk Internet Tunnel", "Verbinden Sie ihren Router ueber das Internet mit anderen Freifunknetzen.")
	gvpn.rmempty = false
	function gvpn.cfgvalue(self, section)
		return uci:get("freifunk", "wizard", "gvpn")
	end
	function gvpn.write(self, section, value)
		uci:set("freifunk", "wizard", "gvpn", value)
		uci:save("freifunk")
	end
	gvpnip = f:field(Value, "gvpnip", translate("IPv4-Address"))
	gvpnip:depends("gvpn", "1")
	function gvpnip.cfgvalue(self, section)
		return uci:get("l2gvpn", "bbb", "ip") or uci:get("network", "gvpn", "ipaddr")
	end
	function gvpnip.validate(self, value)
		local x = ip.IPv4(value)
		return ( x and x:prefix() == 32 ) and x:string() or ""
	end
end

-------------------- Control --------------------
function f.handle(self, state, data)
	if state == FORM_VALID then
		local debug = uci:get("freifunk", "wizard", "debug")
		if debug == "1" then
			if data.pw1 then
				local stat = luci.sys.user.setpasswd("root", data.pw1) == 0
				if stat then
					f.message = translate("Password successfully changed")
				else
					f.errmessage = translate("Unknown Error")
				end
			end
			data.pw1 = nil
			data.pw2 = nil
			luci.http.redirect(luci.dispatcher.build_url("admin", "system"))
		else
			if data.pw1 then
				local stat = luci.sys.user.setpasswd("root", data.pw1) == 0
--				if stat then
--					f.message = translate("a_s_changepw_changed")
--			else
--				f.errmessage = translate("unknownerror")
				end
			data.pw1 = nil
			data.pw2 = nil
			uci:commit("freifunk")
			uci:commit("wireless")
			uci:commit("network")
			uci:commit("dhcp")
			if has_firewall then
				uci:commit("firewall")
				uci:commit("freifunk_p2pblock")
			end
			if has_splash then
				uci:commit("luci_splash")
			end
			if has_splash_enable then
				sys.init.enable("luci_splash")
			end
			uci:commit("system")
			uci:commit("uhttpd")
			uci:commit("olsrd")
			uci:commit("manager")
			if has_auto_ipv6_gw then
				uci:commit("auto_ipv6_gw")
			end
			if has_auto_ipv6_node then
				uci:commit("auto_ipv6_node")
			end
			if has_qos then
				uci:commit("qos")
			end
			if has_l2gvpn then
				uci:commit("l2gvpn")
			end
			if has_ovpn then
				uci:commit("openvpn")
				uci:commit("freifunk-watchdog")
			end
			if has_pr then
				uci:commit("freifunk-policyrouting")
			end
			if has_6relayd then
				uci:commit("6relayd")
			end

-- the following line didn't work without admin-mini, for now i just replaced it with sys.exec... soma
			luci.http.redirect(luci.dispatcher.build_url("admin", "system", "reboot") .. "?reboot=1")
--			sys.exec("reboot")
		end
		logger("reboot")
		return false
	elseif state == FORM_INVALID then
		self.errmessage = "Ungültige Eingabe: Bitte die Formularfelder auf Fehler prüfen."
		logger("self.errmessage: "..self.errmessage)
	end
	return true
end

local function _strip_internals(tbl)
	tbl = tbl or {}
	for k, v in pairs(tbl) do
		if k:sub(1, 1) == "." then
			tbl[k] = nil
		end
	end
	return tbl
end

-- Configure Freifunk checked
function main.write(self, section, value)
	local community = net:formvalue(section) or "Freifunk"
	local external = "profile_"..community
	local suffix = uci:get_first(external, "community", "suffix") or "olsr"

	-- Invalidate fields
	if not community then
		--net.tag_missing[section] = true
		net.error = { [section] = "missing" }
		logger("missing community: "..section)
		return
	end

	local netname = "wireless"
	local ifcfgname = "wlan"
	local network
	network = ip.IPv4(uci:get_first(external, "community", "mesh_network") or "104.0.0.0/8")

	-- Tune community settings
	if community and uci:get(external, "profile") then
		uci:tset("freifunk", "community", uci:get_all(external, "profile"))
	end
	uci:set("freifunk", "community", "name", community)
	uci:save("freifunk")
	if has_firewall then
		-- Cleanup
		uci:delete_all("firewall","zone", {name="freifunk"})
		uci:delete_all("firewall","forwarding", {dest="freifunk"})
		uci:delete_all("firewall","forwarding", {src="freifunk"})
		uci:delete_all("firewall","rule", {dest="freifunk"})
		uci:delete_all("firewall","rule", {src="freifunk"})
		uci:save("firewall")
		-- Create firewall zone and add default rules (first time)
		--                    firewall_create_zone("name"    , "input" , "output", "forward ", Masqurade)
		local newzone = tools.firewall_create_zone("freifunk", "ACCEPT", "ACCEPT", "REJECT", 1)
		if newzone then
			tools.firewall_zone_add_masq_src("freifunk", "255.255.255.255/32")
			uci:foreach("freifunk", "fw_forwarding", function(section)
				uci:section("firewall", "forwarding", nil, section)
			end)
			uci:foreach(external, "fw_forwarding", function(section)
				uci:section("firewall", "forwarding", nil, section)
			end)
	
			uci:foreach("freifunk", "fw_rule", function(section)
				uci:section("firewall", "rule", nil, section)
			end)
			uci:foreach(external, "fw_rule", function(section)
				uci:section("firewall", "rule", nil, section)
			end)
		end
		uci:save("firewall")
	end
	if has_splash then
		-- Delete old splash
		uci:delete_all("luci_splash", "subnet")
	end

	-- Delete olsrdv4
	uci:delete_all("olsrd", "olsrd")
	local olsrbase = uci:get_all("freifunk", "olsrd") or {}
	util.update(olsrbase, uci:get_all(external, "olsrd") or {})
	if has_ipv6 then
		olsrbase.IpVersion='6and4'
		uci:foreach("olsrd", "LoadPlugin",
		function(s)
			if s.library == "olsrd_jsoninfo.so.0.0" then
				uci:set("olsrd", s['.name'], "accept", "0.0.0.0")
			end
		end)
	elseif has_ipv6_only then
		olsrbase.IpVersion='6'
		uci:foreach("olsrd", "LoadPlugin",
		function(s)
			if s.library == "olsrd_jsoninfo.so.0.0" then
				uci:set("olsrd", s['.name'], "accept", "::")
			end
		end)
	else
		olsrbase.IpVersion='4'
		uci:foreach("olsrd", "LoadPlugin",
		function(s)
			if s.library == "olsrd_jsoninfo.so.0.0" then
				uci:set("olsrd", s['.name'], "accept", "0.0.0.0")
			end
		end)
	end

	if has_6relayd then
		uci:delete("6relayd", "default")
		uci:section("6relayd","server","default", {
			rd = "server",
			dhcpv6 = "server",
			management_level = "1",
			compat_ula = "1",
			always_assume_default = "1"
		})
		uci:save("6relayd")
	end

	-- Internet sharing
	local share_value = "0"
	if has_wan then
		share_value = sharenet:formvalue(section) or "0"
		uci:set("freifunk", "wizard", "share_value", share_value)
	end
	if share_value == "1" then
		olsrbase.SmartGateway="yes"
		olsrbase.SmartGatewaySpeed="500 10000"
		if has_qos then
			qosd = wanqosdown:formvalue(section)
			qosu = wanqosup:formvalue(section)
			if (qosd and qosd ~= "") and (qosu and qosd ~= "")  then
				olsrbase.SmartGatewaySpeed=qosu.." "..qosd
				olsrbase.RtTableDefault="112"
				olsrbase.RtTableTunnel="113"
			end
		end
		if has_pr then
			olsrbase.RtTable="111"
			olsrbase.RtTableDefault="112"
			olsrbase.RtTableTunnel="113"
		end
		uci:section("network", "interface", "tunl0", {
			proto  = "none",
			ifname = "tunl0"
		})
		if has_firewall then
			tools.firewall_zone_add_interface("freifunk", "tunl0")
		end
	end
	uci:section("olsrd", "olsrd", nil, olsrbase)

	-- Delete interface defaults
	uci:delete_all("olsrd", "InterfaceDefaults")
	-- Write new olsrv4 interface
	local olsrifbase = uci:get_all("freifunk", "olsr_interface") or {}
	util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
	uci:section("olsrd", "InterfaceDefaults", nil, olsrifbase)

	-- Delete olsrdv4 old p2pd settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_mdns.so.1.0.0"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_p2pd.so.0.1.0"})
	-- Write olsrdv4 new p2pd settings
	uci:section("olsrd", "LoadPlugin", nil, {
		library     = "olsrd_p2pd.so.0.1.0",
		P2pdTtl     = 10,
		UdpDestPort = "224.0.0.251 5353",
		ignore      = 1,
	})
	-- Delete http plugin
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_httpinfo.so.0.1"})

	-- Delete olsrdv4 old interface
	uci:delete_all("olsrd", "Interface")
	uci:delete_all("olsrd", "Hna4")
	uci:delete_all("olsrd", "Hna6")
	
	if has_6relayd then
		uci:delete("6relayd","default","network")
	end

	-- Create wireless ip4/ip6 and firewall config
	uci:foreach("wireless", "wifi-device",
	function(sec)
		local device = sec[".name"]
		local mesh_device = wifi_tbl[device]["dev"]:formvalue(section)
		local br_device = wifi_tbl[device]["dhcpbr"]:formvalue(section)
		if not mesh_device and not br_device then
			logger("olsr disable: "..device)
			return
		end
		local node_ip
		if mesh_device then
			node_ip = wifi_tbl[device]["meship"]:formvalue(section)
			logger("node_ip: "..node_ip)
			if node_ip then
				node_ip = ip.IPv4(node_ip)
			end
			if not node_ip or not network or not network:contains(node_ip) then
				--wifi_tbl[device]["meship"].tag_missing[section] = true
				wifi_tbl[device]["meship"].error = { [section] = "missing" }
				node_ip = nil
				logger("missing node_ip or not network:contains(node_ip): "..device.." "..section)
				return
			end
		end
		-- rename the wireless interface s/wifi/wireless/
		local nif
		local ifcfg
		local device_l = {
			"wifi",
			"wl",
			"wlan",
			"radio"
		}
		for i, v in ipairs(device_l) do
			if string.find(device, v) then
				nif = string.gsub(device, v, netname)
				ifcfg = string.gsub(device, v, ifcfgname)
			end
		end
		-- Cleanup
		tools.wifi_delete_ifaces(device)
		tools.wifi_delete_ifaces("wlan")
		-- tools.network_remove_interface(device)
		uci:delete("network", device .. "dhcp")
		uci:delete("network", device)
		if has_firewall then
			tools.firewall_zone_remove_interface("freifunk", device)
			tools.firewall_zone_remove_interface("freifunk", nif)
		end
		if has_splash then
			-- Delete old splash
			uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
			uci:delete_all("luci_splash", "iface", {network=nif.."dhcp", zone="freifunk"})
		end
		-- tools.network_remove_interface(nif)
		uci:delete("network", nif .. "dhcp")
		uci:delete("network", nif)
		-- Delete old dhcp
		uci:delete("dhcp", device)
		uci:delete("dhcp", device .. "dhcp")
		uci:delete("dhcp", nif)
		uci:delete("dhcp", nif .. "dhcp")
		-- Get device info
		local iw = luci.sys.wifi.getiwinfo(device)
		-- New Config
		-- Tune wifi device
		local ssid = uci:get_first(external, "community", "ssid")
		local ssiddot = string.find(ssid,'%..*')
		local ssidshort
		if ssiddot then
			ssidshort = string.sub(ssid,ssiddot)
		else
			ssidshort = ssid
		end
		local devconfig = uci:get_all("freifunk", "wifi_device") or {}
		util.update(devconfig, uci:get_all(external, "wifi_device") or {})
		local channel = wifi_tbl[device]["chan"]:formvalue(section) or "default"
		logger("channel: "..channel)
		local hwtype = sec.type
		local hwmode
		local pre
		local has_n
		if hwtype == "mac80211" then
			hwmode = sec.hwmode
			if string.find(hwmode, "n") then
				has_n = "n"
			end
		end
		local hwmode = "11"..(has_n or "")
		--local bssid = "02:CA:FF:EE:BA:BE"
		local bssid
		local mrate = 5500
		local freqlist
		if iw and iw.freqlist then
			freqlist = iw.freqlist
			local channel_c
			if channel ~= "default" then
				channel = tonumber(channel)
				--for _, f in ipairs(freqlist) do
				--	if not f.restricted then
				--		if f.channel == channel then
							channel_c = 1
				--			break
				--		end
				--	end
				--end
				--if not channel_c then
				--	logger("channel: "..channel.." no support or restricted")
				--	channel = "default"
				--end
			end
		end
		
		if channel == "default" then
			local channel_f
			if (type(devconfig.channel) == "table") then
				for _, defchan in pairs(devconfig.channel) do
					defchan = tonumber(defchan)
					channel = defchan
					if freqlist then
						for _, f in ipairs(freqlist) do
							if not f.restricted then
								channel = tonumber(f.channel)
								if f.channel == defchan then
									channel_f = 1
									break
								end
							end
						end
						if channel_f then
							break
						end
					end
				end
				ssid = "ch" .. channel .. ssidshort
			else
				defchan = tonumber(devconfig.channel or 13)
				channel = defchan
				if freqlist then
					for _, f in ipairs(freqlist) do
						if not f.restricted then
							channel = f.channel
							if f.channel == defchan then
								break
							end
						end
					end
				end
				ssid = "ch" .. channel .. ssidshort
			end
			if channel > 0 and channel < 10 then
				pre = 2
				hwmode = hwmode.."g"
				mrate = ""
				bssid = channel .. "2:CA:FF:EE:BA:BE"
			elseif channel == 10 then
				pre = 2
				hwmode = hwmode.."g"
				mrate = ""
				bssid = "02:CA:FF:EE:BA:BE"
			elseif channel >= 11 and channel <= 14 then
				pre = 2
				hwmode = hwmode.."g"
				bssid = string.format("%X",channel) .. "2:CA:FF:EE:BA:BE"
			elseif channel >= 36 and channel <= 64 then
				pre = 5
				hwmode = hwmode.."a"
				mrate = ""
				outdoor = 0
				bssid = "02:" .. channel ..":CA:FF:EE:EE"
			elseif channel >= 100 and channel <= 140 then
				pre = 5
				hwmode = hwmode.."a"
				mrate = ""
				outdoor = 1
				bssid = "12:" .. string.sub(channel, 2) .. ":CA:FF:EE:EE"
			end
			ssid = uci:get(external,"ssidscheme",channel) or ssid
			bssid = uci:get(external,"bssidscheme",channel) or bssid
			devconfig.channel = channel
		else
			logger("channel: "..channel)
			channel = tonumber(channel)
			if channel > 0 and channel < 10 then
				pre = 2
				hwmode = hwmode.."g"
				mrate = ""
				bssid = channel .. "2:CA:FF:EE:BA:BE"
			elseif channel == 10 then
				pre = 2
				hwmode = hwmode.."g"
				mrate = ""
				bssid = "02:CA:FF:EE:BA:BE"
			elseif channel >= 11 and channel <= 14 then
				pre = 2
				hwmode = hwmode.."g"
				mrate = ""
				bssid = string.format("%X",channel) .. "2:CA:FF:EE:BA:BE"
			elseif channel >= 36 and channel <= 64 then
				pre = 5
				hwmode = hwmode.."a"
				mrate = ""
				outdoor = 0
				bssid = "02:" .. channel ..":CA:FF:EE:EE"
			elseif channel >= 100 and channel <= 140 then
				pre = 5
				hwmode = hwmode.."a"
				mrate = ""
				outdoor = 1
				bssid = "12:" .. string.sub(channel, 2) .. ":CA:FF:EE:EE"
			end
			ssid = "ch" .. channel .. ssidshort
			devconfig.channel = channel
			ssid = uci:get(external,"ssidscheme",channel) or ssid
			bssid = uci:get(external,"bssidscheme",channel) or bssid
		end
		devconfig.hwmode = hwmode
		devconfig.outdoor = outdoor
		if has_n then
			local ht40plus = {
				1,2,3,4,5,6,7,
				36,44,52,60,100,108,116,124,132
			}
			for i, v in ipairs(ht40plus) do
				if v == channel then
					devconfig.htmode = 'HT40+'
					devconfig.noscan = '1'
				end
			end
			local ht40minus = {
				8,9,10,11,12,13,14,
				40,48,56,64,104,112,120,128,136
			}
			for i, v in ipairs(ht40minus) do
				if v == channel then
					devconfig.htmode = 'HT40-'
					devconfig.noscan = '1'
				end
			end
			local ht20 = {
				140
			}
			for i, v in ipairs(ht20) do
				if v == channel then
					devconfig.htmode = 'HT20'
				end
			end
		end
		local advanced = wifi_tbl[device]["advanced"]:formvalue(section)
		if advanced then
			local hwmode = wifi_tbl[device]["hwmode"]:formvalue(section)
			if hwmode then
				devconfig.hwmode = hwmode
			end
			local htmode = wifi_tbl[device]["htmode"]:formvalue(section)
			if htmode then
				devconfig.htmode = htmode
			end
			local txpower = wifi_tbl[device]["txpower"]:formvalue(section)
			if txpower then
				devconfig.txpower = txpower
			end
			local distance = wifi_tbl[device]["distance"]:formvalue(section)
			if distance then
				devconfig.distance = distance
			end
			local txantenna = wifi_tbl[device]["txantenna"]:formvalue(section)
			if txantenna then
				devconfig.txantenna = txantenna
			end
			local rxantenna = wifi_tbl[device]["rxantenna"]:formvalue(section)
			if rxantenna then
				devconfig.rxantenna = rxantenna
			end
		end
		uci:tset("wireless", device, devconfig)
		local ifconfig
		-- Create wifi iface
		if mesh_device then
			ifconfig = uci:get_all("freifunk", "wifi_iface")
			util.update(ifconfig, uci:get_all(external, "wifi_iface") or {})
			ifconfig.device = device
			ifconfig.mcast_rate = mrate
			ifconfig.network = nif
			ifconfig.ifname = ifcfg.."-adhoc-"..pre
			if ssid then
				-- See Table https://pberg.freifunk.net/moin/channel-bssid-essid 
				ifconfig.ssid = ssid
			else
				ifconfig.ssid = "olsr.freifunk.net"
			end
			-- See Table https://pberg.freifunk.net/moin/channel-bssid-essid
			if bssid then
				ifconfig.bssid = bssid
			end
			ifconfig.encryption="none"
			-- Read Preset 
			local prenetconfig = uci:get_all("freifunk", "interface") or {}
			util.update(prenetconfig, uci:get_all(external, "interface") or {})
			prenetconfig.proto = "static"
			prenetconfig.ipaddr = node_ip:host():string()
			if node_ip:prefix() < 32 then
				prenetconfig.netmask = node_ip:mask():string()
			end
			prenetconfig.ip6assign=64
			uci:section("network", "interface", nif, prenetconfig)
			if has_6relayd then
				local rifn = uci:get_list("6relayd","default","network") or {}
				table.insert(rifn,nif)
				uci:set_list("6relayd","default","network",rifn)
				uci:save("6relayd")
			end
			local new_hostname = node_ip:string():gsub("%.", "-")
			uci:set("freifunk", "wizard", "hostname", new_hostname)
			uci:save("freifunk")
			if has_firewall then
				tools.firewall_zone_add_interface("freifunk", nif)
				uci:save("firewall")
			end
			-- Write new olsrv4 interface
			local olsrifbase = {}
			olsrifbase.interface = nif
			olsrifbase.ignore    = "0"
			uci:section("olsrd", "Interface", nil, olsrifbase)
			-- Collect MESH DHCP IP NET
			local client = wifi_tbl[device]["client"]:formvalue(section)
			if client then
				local vap = wifi_tbl[device]["vap"]:formvalue(section)
				local dhcpmeshnet = wifi_tbl[device]["dhcpmesh"]:formvalue(section)
				if dhcpmeshnet then
					dhcpmeshnet = ip.IPv4(dhcpmeshnet)
				end
				if dhcpmeshnet then
					if not dhcpmeshnet:minhost() or not dhcpmeshnet:mask() then
						--wifi_tbl[device]["dhcpmesh"].tag_missing[section] = true
						wifi_tbl[device]["dhcpmesh"].error = { [section] = "missing" }
						dhcpmeshnet = nil
						logger("missing ndhcpmeshnet: "..device.." "..section)
						return
					end
					dhcp_ip = dhcpmeshnet:minhost():string()
					dhcp_mask = dhcpmeshnet:mask():string()
					dhcp_network = dhcpmeshnet:network():string()
					uci:section("olsrd", "Hna4", nil, {
						netmask  = dhcp_mask,
						netaddr  = dhcp_network
					})
					uci:foreach("olsrd", "LoadPlugin",
						function(s)
							if s.library == "olsrd_p2pd.so.0.1.0" then
								uci:set("olsrd", s['.name'], "ignore", "1")
								local nonolsr = uci:get_list("olsrd", s['.name'], "NonOlsrIf") or {}
								if vap then
									table.insert(nonolsr,nif.."dhcp")
								else
									table.insert(nonolsr,nif)
								end
								uci:set_list("olsrd", s['.name'], "NonOlsrIf", nonolsr)
							end
						end)
				else
					uci:delete("freifunk", "wizard", "dhcpmesh_" .. device)
					if has_firewall then
						local subnet_prefix = tonumber(uci:get_first("profile_"..community, "community", "splash_prefix")) or 27
						local pool_network = uci:get_first("profile_"..community, "community", "splash_network") or "10.104.0.0/16"
						local pool = luci.ip.IPv4(pool_network)
						local ip = tostring(node_ip)
						if pool and ip then
							local hosts_per_subnet = 2^(32 - subnet_prefix)
							local number_of_subnets = (2^pool:prefix())/hosts_per_subnet
							local seed1, seed2 = ip:match("(%d+)%.(%d+)$")
							if seed1 and seed2 then
								math.randomseed(seed1 * seed2)
							end
							local subnet = pool:add(hosts_per_subnet * math.random(number_of_subnets))
							dhcp_ip = subnet:network(subnet_prefix):add(1):string()
							dhcp_mask = subnet:mask(subnet_prefix):string()
							dhcp_net = luci.ip.IPv4(dhcp_ip,dhcp_mask)
								tools.firewall_zone_add_masq_src("freifunk", dhcp_net:string())
								tools.firewall_zone_enable_masq("freifunk")
						end
					end
				end
				if dhcp_ip and dhcp_mask then
					-- Create alias
					local aliasbase = uci:get_all("freifunk", "alias") or {}
					util.update(aliasbase, uci:get_all(external, "alias") or {})
					aliasbase.ipaddr = dhcp_ip
					aliasbase.netmask = dhcp_mask
					aliasbase.proto = "static"
					if vap then
						local vap_ssid = wifi_tbl[device]["vapssid"]:formvalue(section)
						if(string.len(vap_ssid)==0) then
							vap_ssid = "AP"..channel..ssidshort
						end
						uci:set("freifunk", "wizard", "vapssid_" .. device, vap_ssid)
						aliasbase.ip6assign=64
						if has_6relayd then
							local rifn = uci:get_list("6relayd","default","network") or {}
							table.insert(rifn,nif.."dhcp")
							uci:set_list("6relayd","default","network",rifn)
							uci:save("6relayd")
						end
						uci:section("network", "interface", nif .. "dhcp", aliasbase)
						uci:section("wireless", "wifi-iface", nil, {
							device=device,
							mode="ap",
							encryption ="none",
							network=nif.."dhcp",
							ifname=ifcfg.."-master-"..pre,
							ssid=vap_ssid
						})
						if has_firewall then
							tools.firewall_zone_add_interface("freifunk", nif .. "dhcp")
						end
						uci:save("wireless")
						uci:save("freifunk")
						ifconfig.mcast_rate = nil
						ifconfig.encryption="none"
					else
						--this does not work
						--aliasbase.ifname = "@"..nif
						uci:section("network", "interface", nif .. "dhcp", aliasbase)
						--but a second network entry in wireless work
						ifconfig.network = nif .. " " .. nif .. "dhcp"
						if has_firewall then
							tools.firewall_zone_add_interface("freifunk", nif .. "dhcp")
						end
					end
					uci:save("network")
					-- Create dhcp
					local dhcpbase = uci:get_all("freifunk", "dhcp") or {}
					util.update(dhcpbase, uci:get_all(external, "dhcp") or {})
					dhcpbase.interface = nif .. "dhcp"
					dhcpbase.force = 1
					dhcpbase.ignore = 0
					uci:section("dhcp", "dhcp", nif .. "dhcp", dhcpbase)
					uci:set_list("dhcp", nif .. "dhcp", "dhcp_option", "119,olsr")
					if has_firewall then
						-- Create firewall settings
						uci:delete_all("firewall", "rule", {
							src="freifunk",
							proto="udp",
							dest_port="53"
						})
						uci:section("firewall", "rule", nil, {
							src="freifunk",
							proto="udp",
							dest_port="53",
							target="ACCEPT"
						})
						uci:delete_all("firewall", "rule", {
							src="freifunk",
							proto="udp",
							src_port="68",
							dest_port="67"
						})
						uci:section("firewall", "rule", nil, {
							src="freifunk",
							proto="udp",
							src_port="68",
							dest_port="67",
							target="ACCEPT"
						})
						uci:delete_all("firewall", "rule", {
							src="freifunk",
							proto="tcp",
							dest_port="8082",
						})
						uci:section("firewall", "rule", nil, {
							src="freifunk",
							proto="tcp",
							dest_port="8082",
							target="ACCEPT"
						})
						if has_splash then
							local dhcpsplash = wifi_tbl[device]["dhcpsplash"]:formvalue(section)
							if dhcpsplash  then
								-- Register splash interface
								uci:section("luci_splash", "iface", nil, {network=nif.."dhcp", zone="freifunk"})
								-- Make sure that luci_splash is enabled
								has_splash_enable = 1
							end
						end
					end
				end
			end
		end
		if br_device then
			local vap_ssid = wifi_tbl[device]["vapssid"]:formvalue(section)
			if(string.len(vap_ssid)==0) then
				vap_ssid = "AP"..channel..ssidshort
			end
			uci:set("freifunk", "wizard", "vapssid_" .. device, vap_ssid)
			uci:section("wireless", "wifi-iface", nil, {
				device=device,
				mode="ap",
				encryption ="none",
				network="lan",
				ifname=ifcfg.."-master-"..pre,
				ssid=vap_ssid
			})
		end
		--Write Ad-Hoc wifi section after AP wifi section
		if mesh_device then
			uci:section("wireless", "wifi-iface", nil, ifconfig)
		end
		uci:save("network")
		uci:save("wireless")
		uci:save("network")
		if has_firewall then
			uci:save("firewall")
		end
		if has_splash then
			uci:save("luci_splash")
		end
		uci:save("dhcp")
	end)
	-- Create wired ip and firewall config
	uci:foreach("network", "interface",
		function(sec)
		local device = sec[".name"]
		for i, v in ipairs(device_il) do
			if string.find(device, v) then
				logger("olsr ignore: "..device.." "..section)
				return
			end
		end
		local mesh_device = wired_tbl[device]["dev"]:formvalue(section)
		if not mesh_device then
			logger("olsr disable: "..device.." "..section)
			return
		end
		logger("olsr enable: "..device.." "..section)
		--local node_ip
		local node_ip = wired_tbl[device]["meship"]:formvalue(section)
		logger("node_ip: "..node_ip)
		if node_ip then
			node_ip = ip.IPv4(node_ip)
		end
		if not node_ip or not network or not network:contains(node_ip) then
			--wired_tbl[device]["meship"].tag_missing[section] = true
			wired_tbl[device]["meship"].error = { [section] = "missing" }
			logger("missing node_ip or not network:contains(node_ip)")
			node_ip = nil
			return
		end
		if has_firewall then
			-- Cleanup
			tools.firewall_zone_remove_interface(device, device)
			if device ~= "freifunk" then
				uci:delete_all("firewall","zone", {name=device})
				uci:delete_all("firewall","forwarding", {src=device})
				uci:delete_all("firewall","forwarding", {dest=device})
			end
		end
		uci:delete("network", device .. "dhcp")
		-- Delete old dhcp
		uci:delete("dhcp", device)
		uci:delete("dhcp", device .. "dhcp")
		if has_splash then
			-- Delete old splash
			uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
		end
		-- New Config
		local prenetconfig = uci:get_all("freifunk", "interface") or {}
		util.update(prenetconfig, uci:get_all(external, "interface") or {})
		prenetconfig.proto = "static"
		prenetconfig.ipaddr = node_ip:host():string()
		if node_ip:prefix() < 32 then
			prenetconfig.netmask = node_ip:mask():string()
		end
		prenetconfig.ip6addr = ''
		prenetconfig.ip6assign=64
		prenetconfig.gateway = ''
		prenetconfig.username = ''
		prenetconfig.password = ''
		uci:section("network", "interface", device, prenetconfig)
		uci:save("network")
		if has_6relayd then
			local rifn = uci:get_list("6relayd","default","network") or {}
			table.insert(rifn,device)
			uci:set_list("6relayd","default","network",rifn)
			uci:save("6relayd")
		end
		if has_wan and device == "wan" then
			has_wan=nil
			share_value=0
		end
		if has_lan and device == "lan" then
			has_lan=nil
		end
		local new_hostname = node_ip:string():gsub("%.", "-")
		uci:set("freifunk", "wizard", "hostname", new_hostname)
		uci:save("freifunk")
		if has_firewall then
			tools.firewall_zone_add_interface("freifunk", device)
			uci:save("firewall")
		end
		-- Write new olsrv4 interface
		local olsrifbase = {}
		olsrifbase.interface = device
		olsrifbase.ignore    = "0"
		olsrifbase.Mode = 'ether'
		uci:section("olsrd", "Interface", nil, olsrifbase)
		-- Collect MESH DHCP IP NET
		local client = wired_tbl[device]["client"]:formvalue(section)
		if client then
			local dhcpmeshnet = wired_tbl[device]["dhcpmesh"]:formvalue(section)
			if dhcpmeshnet then
				dhcpmeshnet = ip.IPv4(dhcpmeshnet)
			end
			if dhcpmeshnet then
				if not dhcpmeshnet:minhost() or not dhcpmeshnet:mask() then
					--wired_tbl[device]["dhcpmesh"].tag_missing[section] = true
					wired_tbl[device]["dhcpmesh"].error = { [section] = "missing" }
					dhcpmeshnet = nil
					logger("missing dhcpmeshnet"..device.." "..section)
					return
				end
				dhcp_ip = dhcpmeshnet:minhost():string()
				dhcp_mask = dhcpmeshnet:mask():string()
				dhcp_network = dhcpmeshnet:network():string()
				uci:section("olsrd", "Hna4", nil, {
					netmask = dhcp_mask,
					netaddr = dhcp_network
				})
				uci:foreach("olsrd", "LoadPlugin",
					function(s)		
						if s.library == "olsrd_p2pd.so.0.1.0" then
							uci:set("olsrd", s['.name'], "ignore", "1")
							local nonolsr = uci:get_list("olsrd", s['.name'], "NonOlsrIf") or {}
							table.insert(nonolsr,device)
							uci:set_list("olsrd", s['.name'], "NonOlsrIf", nonolsr)
						end
					end)
			else
				uci:delete("freifunk", "wizard", "dhcpmesh_" .. device)
				local subnet_prefix = tonumber(uci:get_first("profile_"..community, "splash_prefix")) or 27
				local pool_network = uci:get_first("profile_"..community, "splash_network") or "10.104.0.0/16"
				local pool = luci.ip.IPv4(pool_network)
				local ip = tostring(node_ip)
				if pool and ip then
					local hosts_per_subnet = 2^(32 - subnet_prefix)
					local number_of_subnets = (2^pool:prefix())/hosts_per_subnet
					local seed1, seed2 = ip:match("(%d+)%.(%d+)$")
					if seed1 and seed2 then
						math.randomseed(seed1 * seed2)
					end
					local subnet = pool:add(hosts_per_subnet * math.random(number_of_subnets))
					dhcp_ip = subnet:network(subnet_prefix):add(1):string()
					dhcp_mask = subnet:mask(subnet_prefix):string()
					dhcp_net = luci.ip.IPv4(dhcp_ip,dhcp_mask)
					if has_firewall then
						tools.firewall_zone_add_masq_src("freifunk", dhcp_net:string())
						tools.firewall_zone_enable_masq("freifunk")
					end
				end
			end
			if dhcp_ip and dhcp_mask then
				-- Create alias
				local aliasbase = uci:get_all("freifunk", "alias") or {}
				util.update(aliasbase, uci:get_all(external, "alias") or {})
				aliasbase.ifname = "@" .. device
				aliasbase.ipaddr = dhcp_ip
				aliasbase.netmask = dhcp_mask
				aliasbase.proto = "static"
				uci:section("network", "interface", device .. "dhcp", aliasbase)
				if has_firewall then
					tools.firewall_zone_add_interface("freifunk", device .. "dhcp")
				end
				-- Create dhcp
				local dhcpbase = uci:get_all("freifunk", "dhcp") or {}
				util.update(dhcpbase, uci:get_all(external, "dhcp") or {})
				dhcpbase.interface = device .. "dhcp"
				dhcpbase.force = 1
				dhcpbase.ignore = 0
				uci:section("dhcp", "dhcp", device .. "dhcp", dhcpbase)
				uci:set_list("dhcp", device .. "dhcp", "dhcp_option", "119,olsr")
				if has_firewall then
					-- Create firewall settings
					uci:delete_all("firewall", "rule", {
						src="freifunk",
						proto="udp",
						dest_port="53"
					})
					uci:section("firewall", "rule", nil, {
						src="freifunk",
						proto="udp",
						dest_port="53",
						target="ACCEPT"
					})
					uci:delete_all("firewall", "rule", {
						src="freifunk",
						proto="udp",
						src_port="68",
						dest_port="67"
					})
					uci:section("firewall", "rule", nil, {
						src="freifunk",
						proto="udp",
						src_port="68",
						dest_port="67",
						target="ACCEPT"
					})
					uci:delete_all("firewall", "rule", {
						src="freifunk",
						proto="tcp",
						dest_port="8082",
					})
					uci:section("firewall", "rule", nil, {
						src="freifunk",
						proto="tcp",
						dest_port="8082",
						target="ACCEPT"
					})
					-- Register splash
					if has_splash then
						local dhcpsplash = wired_tbl[device]["dhcpsplash"]:formvalue(section)
						if dhcpsplash then
							-- Register splash interface
							uci:section("luci_splash", "iface", nil, {network=device.."dhcp", zone="freifunk"})
							-- Make sure that luci_splash is enabled
							has_splash_enable = 1
						end
					end
				end
			end
		end
		uci:save("olsr")
		uci:save("wireless")
		uci:save("network")
		if has_firewall then
			uci:save("firewall")
		end
		if has_splash then
			uci:save("luci_splash")
		end
		uci:save("dhcp")
	end)
	-- END Create wired ip and firewall config

	if has_firewall then
		-- Enforce firewall include
		local has_include = false
		uci:foreach("firewall", "include",
			function(section)
				if section.path == "/etc/firewall.freifunk" then
					has_include = true
				end
			end)
	
		if not has_include then
			uci:section("firewall", "include", nil,
				{ path = "/etc/firewall.freifunk" })
		end
		-- Allow state: invalid packets
		uci:foreach("firewall", "defaults",
			function(section)
				uci:set("firewall", section[".name"], "drop_invalid", "0")
			end)
	
		-- Prepare advanced config
		local has_advanced = false
		uci:foreach("firewall", "advanced",
			function(section) has_advanced = true end)
	
		if not has_advanced then
			uci:section("firewall", "advanced", nil,
				{ tcp_ecn = "0", ip_conntrack_max = "8192", tcp_westwood = "1" })
		end
		uci:save("firewall")

		if has_splash_enable then
			network_mask = network:mask():string()
			network_network = network:network():string()
			-- Add community ip range
			uci:section("luci_splash", "subnet", nil, {ipaddr=network_network, netmask=network_mask})
			uci:save("luci_splash")
		end
	end

	local loc = location:formvalue(section)
	if loc then
		uci:foreach("system", "system", function(s)
			uci:set("system", s[".name"], "location",loc)
		end)
	end
	uci:save("system")

	local new_hostname = uci:get("freifunk", "wizard", "hostname")
	local old_hostname = sys.hostname()
	local custom_hostname = hostname:formvalue(section)

	uci:foreach("system", "system",
		function(s)
			-- Make crond silent
			uci:set("system", s[".name"], "cronloglevel", "10")
			-- Make set timzone and zonename
			uci:set("system", s[".name"], "zonename", "Europe/Berlin")
			uci:set("system", s[".name"], "timezone", 'CET-1CEST,M3.5.0,M10.5.0/3')
			-- Set hostname
			if custom_hostname then
				if custom_hostname == "OpenWrt" or custom_hostname:match("^%d+-%d+-%d+-%d+$") then
					if new_hostname then
						uci:set("system", s[".name"], "hostname", new_hostname)
						sys.hostname(new_hostname)
					end
				else
					uci:set("system", s[".name"], "hostname", custom_hostname)
					sys.hostname(custom_hostname)
				end
			else
				if new_hostname then
					if old_hostname == "OpenWrt" or old_hostname:match("^%d+-%d+-%d+-%d+$") then
						uci:set("system", s[".name"], "hostname", new_hostname)
						sys.hostname(new_hostname)
					end
				end
			end
		end)

	-- Create http splash port 8082
	uci:set_list("uhttpd","main","listen_http",{"80"})
	uci:set_list("uhttpd","main","listen_https",{"443"})
	uci:save("uhttpd")

	-- Read geos
	local latval = tonumber(lat:formvalue(section))
	local lonval = tonumber(lon:formvalue(section))
	local latval_com = tonumber(uci:get_first("profile_"..community, "community", "latitude"))
	local lonval_com = tonumber(uci:get_first("profile_"..community, "community", "longitude"))
	if latval and latval == 52 then
		latval = nil
	end
	if latval and latval == latval_com then
		latval = nil
	end
	if lonval and lonval == 52 then
		lonval = nil
	end
	if lonval and lonval == lonval_com then
		lonval = nil
	end
	-- Save latlon to system too
	if latval and lonval then
		uci:foreach("system", "system", function(s)
			uci:set("system", s[".name"], "latlon",string.format("%.15f %.15f", latval, lonval))
			uci:set("system", s[".name"], "latitude",string.format("%.15f", latval))
			uci:set("system", s[".name"], "longitude",string.format("%.15f", lonval))
		end)
	else
		uci:foreach("system", "system", function(s)
			uci:delete("system", s[".name"], "latlon")
			uci:delete("system", s[".name"], "latitude")
			uci:delete("system", s[".name"], "longitude")
		end)
	end
	uci:save("system")

	-- Delete old watchdog settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_watchdog.so.0.1"})
	-- Write new watchdog settings
	uci:section("olsrd", "LoadPlugin", nil, {
		library  = "olsrd_watchdog.so.0.1",
		file     = "/var/run/olsrd.watchdog",
		interval = "30"
	})

	-- Delete old nameservice settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_nameservice.so.0.3"})
	-- Write new nameservice settings
	uci:section("olsrd", "LoadPlugin", nil, {
		library     = "olsrd_nameservice.so.0.3",
		suffix      = "." .. suffix ,
		hosts_file  = "/tmp/hosts/olsr",
		latlon_file = "/var/run/latlon.js",
		services_file = "/var/etc/services.olsr"
	})

	if has_ipv6 then
		local ula_prefix = uci:get("network","globals","ula_prefix")
		if ula_prefix then
			ula_prefix = ip.IPv6(ula_prefix)
			if ula_prefix:is6() then
				uci:section("olsrd", "Hna6", nil, {
					prefix = ula_prefix:prefix(),
					netaddr = ula_prefix:network():string()
				})
			end
		end
		local lanprefixs = uci:get_list("network","lan","ip6prefix") or {}
		for i, p in ipairs(lanprefixs) do
			p = ip.IPv6(p)
			if p:is6() then
				uci:section("olsrd", "Hna6", nil, {
					prefix = p:prefix(),
					netaddr = p:network():string()
				})
				uci:foreach("olsrd", "LoadPlugin",
				function(s)
					if s.library == "olsrd_nameservice.so.0.3" then
						local service = uci:get_list("olsrd", s['.name'], "service") or {}
						local hn = "pre"..i.."."..sys.hostname()
						local fqhn = hn.."."..suffix
						service[#service+1] = "http://"..fqhn..":80|tcp|"..fqhn.." on "..p:minhost():string()
						uci:set_list("olsrd", s['.name'], "service", service)
						local hosts = uci:get_list("olsrd", s['.name'], "hosts") or {}
						hosts[#hosts+1] = p:minhost():string().." "..hn
						uci:set_list("olsrd", s['.name'], "hosts", hosts)
					end
				end)
			end
		end
	end
	if has_wan and has_6in4 then
		local henet_prefix = henetprefix:formvalue(section)
		local henet_ip6addr = henetip6addr:formvalue(section)
		if henet_prefix and henet_ip6addr then
			henet_prefix = ip.IPv6(henet_prefix)
			henet_ip6addr = ip.IPv6(henet_ip6addr)
			if henet_prefix:is6() and henet_ip6addr:is6() then
				uci:section("olsrd", "Hna6", nil, {
					prefix = henet_prefix:prefix(),
					netaddr = henet_prefix:network():string()
				})
				uci:foreach("olsrd", "LoadPlugin",
				function(s)
					if s.library == "olsrd_nameservice.so.0.3" then
						local service = uci:get_list("olsrd", s['.name'], "service") or {}
						local hn = "henet."..sys.hostname()
						local fqhn = hn.."."..suffix
						service[#service+1] = "http://"..fqhn..":80|tcp|"..fqhn.." on "henet_prefix:minhost():string()
						uci:set_list("olsrd", s['.name'], "service", service)
						local hosts = uci:get_list("olsrd", s['.name'], "hosts") or {}
						hosts[#hosts+1] = henet_prefix:minhost():string().." "..hn
						uci:set_list("olsrd", s['.name'], "hosts", hosts)
					end
				end)
				--Compat for old auto-ipv6-node
				uci:foreach("olsrd", "olsrd",
				function(s)
					uci:set("olsrd", s['.name'], "MainIp", henet_prefix:minhost():string())
				end)
				uci:save("olsr")

				local route6_new = 1
				uci:foreach("network", "route6",
				function(s)
					if s.interface == "henet" and s.target == "::/0" then
						uci:set("network", s['.name'], "gateway", henet_ip6addr:minhost():string())
						route6_new = 0
					end
				end)
				if route6_new == 1 then
					uci:section("network", "route6", nil, {
						interface = "henet",
						target = "::/0",
						gateway = henet_ip6addr:minhost():string()
					})
				end
				uci:save("network")
			end
		end
	end

	-- Make sure that OLSR is enabled
	sys.init.enable("olsrd")

	uci:save("olsrd")

	-- Import hosts and set domain
	uci:foreach("dhcp", "dnsmasq", function(s)
		uci:set("dhcp", s[".name"], "local", "/" .. suffix .. "/")
		uci:set("dhcp", s[".name"], "domain", suffix)
	end)

	uci:save("dhcp")

	local wproto
	local fwanipn
	if has_wan and has_firewall then
		local newzone = tools.firewall_create_zone("wan", "REJECT", "ACCEPT", "REJECT", 1)
		if newzone then
			tools.firewall_zone_add_interface("wan", "wan")
		end
		wproto = wanproto:formvalue(section)
		if wproto and wproto == "static" then
			local fwanip = wanipaddr:formvalue(section)
			local fwannm = wannetmask:formvalue(section)
			if fwanip and fwannm then
				fwanipn=ip.IPv4(fwanip,fwannm)
				if fwanipn then
					tools.firewall_zone_add_masq_src("freifunk", fwanipn:string())
					tools.firewall_zone_enable_masq("freifunk")
				end
			end
		else 
			local wanetm = require "luci.model.network".init()
			local wanet_uci = wanetm:get_network("wan")
			if wanet_uci  and #wanet_uci > 0 then
				local fwanip = wanet_uci:ipaddr()
				local fwannm = wanet_uci:netmask()
				if fwanip and fwannm then
					fwanipn = ip.IPv4(fwanip,fwannm)
				end
			end
		end
		uci:save("firewall")
	end
	local lproto
	if has_lan then
		if has_firewall then
			local newzone = tools.firewall_create_zone("lan", "ACCEPT", "ACCEPT", "ACCEPT", 0)
			if newzone then
				tools.firewall_zone_add_interface("lan", "lan")
				uci:save("firewall")
			end
		end
		lproto = lanproto:formvalue(section)
		if lproto and lproto == "static" then
			-- Delete old dhcp
			uci:delete("network", "landhcp")
			uci:delete("dhcp", "landhcp")
			uci:delete("dhcp", "lan")
			local flanip = lanipaddr:formvalue(section)
			local flannm = lannetmask:formvalue(section)
			if flanip and flannm then
				local flanipn=ip.IPv4(flanip,flannm)
				if flanipn and fwanipn then
					if flanipn:contains(fwanipn) then
						--lanipaddr.tag_missing[section] = true
						lanipaddr.error = { [section] = "missing" }
						logger("error flanipn[".. flanipn:string().."]:contains(fwanipn[".. fwanipn:string().."]) "..section)
						return
					end
					if fwanipn:contains(flanipn) then
						--lannetmask.tag_missing[section] = true
						lannetmask.error = { [section] = "missing" }
						logger("error fwanipn[".. fwanipn:string().."]:contains(flanipn[".. flanipn:string().."]) "..section)
						return
					end
				end
				if flanipn and has_firewall then
					tools.firewall_zone_add_masq_src("freifunk", flanipn:string())
					tools.firewall_zone_enable_masq("freifunk")
					uci:save("firewall")
					-- Create dhcp
					local dhcpbase = {}
					dhcpbase.interface = "lan"
					dhcpbase.ignore = 0
					uci:section("dhcp", "dhcp", "lan", dhcpbase)
					uci:set_list("dhcp", "lan", "dhcp_option", {"119,lan","119,olsr"})
					uci:save("dhcp")
				end
			end
			if has_6relayd then
				local rifn = uci:get_list("6relayd","default","network") or {}
				table.insert(rifn,"lan")
				uci:set_list("6relayd","default","network",rifn)
				uci:save("6relayd")
			end
		end
	end

	-- Delete/Disable gateway plugin
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
	if share_value == "1" then
		uci:set("freifunk", "wizard", "shareconfig", "1")
		uci:save("freifunk")
		if has_auto_ipv6_gw then
			-- Set autoipv6 tunnel mode
			uci:set("auto_ipv6_gw", "tunnel", "enable", "1")
			uci:save("auto_ipv6_gw")
			-- Create tun6to4 interface
			local tun6to4 = {}
			tun6to4.ifname = "tun6to4"
			tun6to4.proto = "none"
			uci:section("network", "interface", "6to4", tun6to4)
			uci:save("network")
		end
		if has_auto_ipv6_node then
			-- Set auto_ipv6_node olsrd mode
			uci:set("auto_ipv6_node", "olsr_node", "enable", "0")
			uci:save("autoipv6")
		end
		local ffvpn_enable="0"
		if has_ovpn then
			ffvpn_enable = ffvpn:formvalue(section)
		end
		-- Enable gateway_plain plugin
		uci:section("olsrd", "LoadPlugin", nil, {library="olsrd_dyn_gw_plain.so.0.4"})
		if has_pr then
			if ffvpn_enable == "1" then
				sys.init.enable("freifunk-policyrouting")
				uci:set("freifunk-policyrouting","pr","enable","1")
				uci:set("freifunk-policyrouting","pr","strict","1")
				uci:set("freifunk-policyrouting","pr","fallback","1")
				uci:set("freifunk-policyrouting","pr","zones", "freifunk")
			else
				sys.init.disable("freifunk-policyrouting")
				uci:set("freifunk-policyrouting","pr","enable","0")
				uci:delete_all("network","rule")
			end
			uci:save("freifunk-policyrouting")
		end
		uci:delete_all("freifunk-watchdog", "process", {process="openvpn"})
		if ffvpn_enable == "1" then
			uci:section("freifunk-watchdog", "process", nil, {
					process="openvpn",
					initscript="/etc/init.d/openvpn"
				})
			uci:save("freifunk-watchdog")
		end

		if has_firewall then
			sys.exec("chmod +x /etc/init.d/freifunk-p2pblock")
			sys.init.enable("freifunk-p2pblock")
		end
		if has_qos then
			uci:delete("qos","wan")
			uci:delete("qos","lan")
			uci:section("qos", 'interface', "wan", {
				enabled     = "1",
				classgroup  = "Default",
			})
			uci:save("qos")
			sys.init.enable("qos")
		end
		if has_firewall then
			uci:set("freifunk_p2pblock", "p2pblock", "interface", "wan")
			uci:save("freifunk_p2pblock")
			uci:delete_all("firewall","zone", {name="wan"})
			uci:section("firewall", "zone", nil, {
				masq	= "1",
				input   = "REJECT",
				forward = "REJECT",
				name    = "wan",
				output  = "ACCEPT",
				network = "wan"
			})
			uci:delete_all("firewall","forwarding", {src="freifunk", dest="wan"})
			uci:section("firewall", "forwarding", nil, {src="freifunk", dest="wan"})
			uci:delete_all("firewall","forwarding", {src="wan", dest="freifunk"})
			uci:section("firewall", "forwarding", nil, {src="wan", dest="freifunk"})
			uci:delete_all("firewall","forwarding", {src="lan", dest="wan"})
			uci:section("firewall", "forwarding", nil, {src="lan", dest="wan"})
			if has_auto_ipv6_gw then
				tools.firewall_zone_add_interface("freifunk", "6to4")
				uci:save("firewall")
			end
			if has_6in4 then
				tools.firewall_zone_add_interface("freifunk", "henet")
				uci:save("firewall")
			end

			if wansec:formvalue(section) == "1" then
					uci:foreach("firewall", "zone",
						function(s)		
							if s.name == "wan" then
								uci:set("firewall", s['.name'], "local_restrict", "1")
								uci:set("firewall", s['.name'], "masq", "1")
								return false
							end
						end)
			end
			if wanopenfw:formvalue(section) == "1" then
					uci:foreach("firewall", "zone",
						function(s)		
							if s.name == "wan" then
								uci:set("firewall", s['.name'], "input", "ACCEPT")
								return false
							end
						end)
			end
			if ffvpn_enable == "1" then
				tools.firewall_zone_add_interface("freifunk", "ffvpn")
				ovpn_server_list = uci:get_list("openvpn","ffvpn","remote")
				for i,v in ipairs(ovpn_server_list) do
					uci:section("firewall", "rule", nil, {
						name="Reject-VPN-over-ff",
						dest="freifunk",
						family="ipv4",
						proto="udp",
						dest_ip=v,
						dest_port="1194",
						target="REJECT"
					})
				end
				uci:save("firewall")
				uci:set("openvpn","ffvpn", "enabled", "1")
				uci:save("openvpn")
			end
		end
		sys.exec('grep wan /etc/crontabs/root >/dev/null || echo "0 6 * * * 	ifup wan" >> /etc/crontabs/root')
	else
		if has_qos then
			uci:set("qos", "wan", "enabled", "0")
			uci:save("qos")
		end
		uci:set("freifunk", "wizard", "shareconfig", "0")
		uci:save("freifunk")
		if has_auto_ipv6_node then
			-- Set auto_ipv6_node olsrd mode
			uci:set("auto_ipv6_node", "olsr_node", "enable", "1")
			uci:save("autoipv6")
		end
		if has_auto_ipv6_gw then
			-- Disable auto_ipv6_gw
			uci:set("auto_ipv6_gw", "tunnel", "enable", "0")
			uci:save("auto_ipv6_gw")
		end
		-- Delete gateway plugins
		uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})
		uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
		-- Disable gateway_plain plugin
		uci:section("olsrd", "LoadPlugin", nil, {
			library     = "olsrd_dyn_gw_plain.so.0.4",
			ignore      = 1,
		})
		if has_pr then
			uci:set("freifunk-policyrouting","pr","enable","0")
			uci:save("freifunk-policyrouting")
		end

		if has_qos then
			sys.init.disable("qos")
		end
		if has_firewall then
			sys.init.disable("freifunk-p2pblock")
			sys.exec("chmod -x /etc/init.d/freifunk-p2pblock")
			uci:delete_all("firewall", "forwarding", {src="freifunk", dest="wan"})
			uci:foreach("firewall", "zone",
				function(s)		
					if s.name == "wan" then
						uci:delete("firewall", s['.name'], "local_restrict")
						return false
					end
				end)
		end
	end

	uci:save("freifunk")
	if has_firewall then
		uci:save("firewall")
	end
	uci:save("olsrd")
	uci:save("system")
end

return f

