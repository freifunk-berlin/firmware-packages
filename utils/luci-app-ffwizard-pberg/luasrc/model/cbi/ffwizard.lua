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

local has_3g     = fs.access("/usr/bin/gcom")
local has_pppoe = fs.glob("/usr/lib/pppd/*/rp-pppoe.so")()
local has_l2gvpn  = fs.access("/usr/sbin/node")
local has_radvd  = fs.access("/etc/config/radvd")
local has_firewall = fs.access("/etc/config/firewall")
local has_rom  = fs.access("/rom/etc")
local has_autoipv6  = fs.access("/usr/bin/auto-ipv6")
local has_qos  = fs.access("/etc/init.d/qos")
local has_ipv6 = fs.access("/proc/sys/net/ipv6")
local has_hb = fs.access("/sbin/heartbeat")
local has_hostapd = fs.access("/usr/sbin/hostapd")
local has_wan = uci:get("network", "wan", "proto")
local has_lan = uci:get("network", "lan", "proto")
local profiles = "/etc/config/profile_"

function get_mac(ix)
	if string.find(ix, "radio") then
		mac = uci:get('wireless',ix,'macaddr')
	else
		mac = fs.readfile("/sys/class/net/" .. ix .. "/address")
	end
	if not mac then
		mac = luci.util.exec("ifconfig " .. ix)
		mac = mac and mac:match(" ([A-F0-9:]+)%s*\n")
	end
		
	if mac then
		mac = mac:sub(1,17)
	end
	if mac and #mac > 0 then
		return mac:lower()
	end
	return "?"
end
function get_ula(imac)
	if string.len(imac) == 17 then
		local mac1 = string.sub(imac,4,8)
		local mac2 = string.sub(imac,10,14)
		local mac3 = string.sub(imac,16,17)
		return 'fdca:ffee:babe::02'..mac1..'ff:fe'..mac2..mac3..'/64'
	end
	return "?"
end
function get_ula_rand(imac)
	if string.len(imac) == 17 then
		local mac0 = sys.exec("head -n 1 /dev/urandom 2>/dev/null | md5sum | cut -b 1-4")
		local mac1 = string.sub(imac,4,8)
		local mac2 = string.sub(imac,10,14)
		local mac3 = string.sub(imac,16,17)
		return 'fdca:ffee:'..mac0..'::02'..mac1..'ff:fe'..mac2..mac3..'/64'
	end
	return "?"
end


-------------------- View --------------------
f = SimpleForm("ffwizward", "Freifunkassistent",
 "Dieser Assistent unterstützt Sie bei der Einrichtung des Routers für das Freifunknetz. Eine ausführliche Dokumentation ist auf http://wiki.freifunk.net/Freifunk_Berlin_Pberg:Firmware#FF_Wizard nach zu lesen")

local newpsswd = has_rom and sys.exec("diff /rom/etc/passwd /etc/passwd")
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

local list = {}
local list = fs_luci.glob(profiles .. "*")

function net.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "net")
end
function net.write(self, section, value)
	uci:set("freifunk", "wizard", "net", value)
	uci:save("freifunk")
end
net_lat = f:field(ListValue, "net_lat", "", "")
net_lat:depends("net", "0")
net_lon = f:field(ListValue, "net_lon", "", "")
net_lon:depends("net", "0")

for k,v in ipairs(list) do
	local n = string.gsub(v, profiles, "")
	local name     = uci:get_first("profile_"..n, "community", "name") or "?"
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
function hostname.cfgvalue(self, section)
	return sys.hostname()
end
function hostname.write(self, section, value)
	uci:set("freifunk", "wizard", "hostname", value)
	uci:save("freifunk")
end
function hostname.validate(self, value)
	if (#value > 16) then
		return
	elseif (string.find(value, "[^%w%_%-]")) then
		return
	else
		return value
	end
end
-- nodeid
local nid
uci:foreach("system", "system", function(s)
		if s.nodeid then
			nid = s.nodeid
		end
end)
if nid then
	nodeid = f:field(Value, "nodeid", "Knoten ID", "Geben Sie Ihrem Freifunk Knoten (Router) eine ID. In diesem Feld steht die Node ID fuer den Heartbeat Daemon")
	nodeid.rmempty = true
	nodeid.optional = false
	function nodeid.cfgvalue(self, section)
		return nid
	end
end

-- location
location = f:field(Value, "location", "Standort", "Geben Sie den Standort ihres Gerätes an")
location.rmempty = false
location.optional = false
function location.cfgvalue(self, section)
	return uci:get("freifunk", "contact", "location")
end
function location.write(self, section, value)
	uci:set("freifunk", "contact", "location", value)
	uci:save("freifunk")
end

-- mail
mail = f:field(Value, "mail", "E-Mail", "Bitte hinterlegen Sie eine Kontaktadresse.")
mail.rmempty = false
mail.optional = false
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
uci:foreach("wireless", "wifi-device",
	function(section)
		local device = section[".name"]
		local hwtype = section.type
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
		local chan = f:field(ListValue, "chan_" .. device, device:upper() .. "  Freifunk Kanal einrichten", "Ihr Gerät und benachbarte Freifunk Knoten müssen auf demselben Kanal senden. Je nach Gerätetyp können Sie zwischen verschiedenen 2,4Ghz und 5Ghz Kanälen auswählen.")
			chan:depends("device_" .. device, "1")
			chan.rmempty = true
			function chan.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "chan_" .. device)
			end
			chan:value('default')
			for i = 1, 14, 1 do
				chan:value(i)
			end
			for i = 36, 64, 4 do
				chan:value(i)
			end
			for i = 100, 140, 4 do
				chan:value(i)
			end
			if hwtype == "atheros" then
				for i = 42, 58, 8 do
					chan:value(i,i.." Atheros Static Turbo")
				end
				for i = 106, 130, 8 do
					chan:value(i,i.." Atheros Static Turbo")
				end
			end
			function chan.write(self, sec, value)
				if value then
					uci:set("freifunk", "wizard", "chan_" .. device, value)
					uci:save("freifunk")
				end
			end
		local advanced = f:field(Flag, "advanced_" .. device, device:upper() .. " Erweiterte WLAN Einstellungen", "advanced")
			advanced:depends("device_" .. device, "1")
			advanced.rmempty = false
			function advanced.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "advanced_" .. device)
			end
			function advanced.write(self, sec, value)
				uci:set("freifunk", "wizard", "advanced_" .. device, value)
				uci:save("freifunk")
			end
		local hwmode = f:field(ListValue, "hwmode_" .. device, device:upper() .. "  "..translate("Mode"))
			hwmode:depends("advanced_" .. device, "1")
			hwmode.rmempty = true
			hwmode.widget = "radio"
			hwmode.orientation = "horizontal"
			hwmode:value("11b", "802.11b")
			hwmode:value("11g", "802.11g")
			hwmode:value("11a", "802.11a")
			hwmode:value("11bg", "802.11b + g")
			if hwtype == "atheros" then
				hwmode:value("11gst", "802.11g + Turbo")
				hwmode:value("11ast", "802.11a + Turbo")
			end
			if hwtype == "broadcom" then
				hwmode:value("11gst", "802.11g + Turbo")
			end
			if hwtype == "mac80211" then
				hwmode:value("11ng", "802.11n + g")
				hwmode:value("11na", "802.11n + a")
			end
			function hwmode.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "hwmode_" .. device)
			end
			function hwmode.write(self, sec, value)
				uci:set("freifunk", "wizard", "hwmode_" .. device, value)
				uci:save("freifunk")
			end
		if hwtype == "mac80211" then
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
		end
		local txpower = f:field(Value, "txpower_" .. device, device:upper() .. "  Sendeleistung", "dBm")
			txpower:depends("advanced_" .. device, "1")
			txpower.rmempty = true
			function txpower.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "txpower_" .. device)
			end
			function txpower.write(self, sec, value)
				uci:set("freifunk", "wizard", "txpower_" .. device, value)
				uci:save("freifunk")
			end
		local distance = f:field(Value, "distance_" .. device, device:upper().."  "..translate("Distance Optimization"), translate("Distance to farthest network member in meters."))
			distance:depends("advanced_" .. device, "1")
			distance.rmempty = true
			function distance.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "distance_" .. device)
			end
			function distance.write(self, sec, value)
				uci:set("freifunk", "wizard", "distance_" .. device, value)
				uci:save("freifunk")
			end
		local txantenna = f:field(ListValue, "txantenna_" .. device, device:upper() .."  ".. translate("Transmitter Antenna"))
			txantenna:depends("advanced_" .. device, "1")
			txantenna.rmempty = true
			txantenna.widget = "radio"
			txantenna.orientation = "horizontal"
			if hwtype == "atheros" then
				txantenna:value("0", translate("auto"))
				txantenna:value("1", translate("Antenna 1"))
				txantenna:value("2", translate("Antenna 2"))
			end
			if hwtype == "broadcom" then
				txantenna:value("3", translate("auto"))
				txantenna:value("0", translate("Antenna 1"))
				txantenna:value("1", translate("Antenna 2"))
			end
			if hwtype == "mac80211" then
				txantenna:value("all", translate("all"))
				txantenna:value("1", translate("Antenna 1"))
				txantenna:value("2", translate("Antenna 2"))
				txantenna:value("4", translate("Antenna 3"))
			end
			function txantenna.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "txantenna_" .. device)
			end
			function txantenna.write(self, sec, value)
				uci:set("freifunk", "wizard", "txantenna_" .. device, value)
				uci:save("freifunk")
			end
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
		local meship = f:field(Value, "meship_" .. device, device:upper() .. "  Mesh IP Adresse einrichten", "Ihre Mesh IP Adresse erhalten Sie von der Freifunk Gemeinschaft in Ihrer Nachbarschaft. Es ist eine netzweit eindeutige Identifikation, z.B. 104.1.1.1.")
			meship:depends("device_" .. device, "1")
			meship.rmempty = true
			function meship.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "meship_" .. device)
			end
			function meship.validate(self, value)
				local x = ip.IPv4(value)
				return ( x and x:prefix() == 32 ) and x:string() or ""
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
		if has_ipv6 then
			local meship6 = f:field(Value, "meship6_" .. device, device:upper() .. "  Mesh IPv6 Adresse einrichten", "Ihre Mesh IP Adresse wird automatisch berechnet")
			meship6:depends("device_" .. device, "1")
			meship6.rmempty = true
			function meship6.cfgvalue(self, section)
				return get_ula(get_mac(device))
			end
		end
	
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
		local dhcpmesh = f:field(Value, "dhcpmesh_" .. device, device:upper() .. "  Mesh DHCP anbieten", "Bestimmen Sie den Adressbereich aus dem Ihre Nutzer IP Adressen erhalten. Es wird empfohlen einen Adressbereich aus Ihrer lokalen Freifunk Gemeinschaft zu nutzen. Der Adressbereich ist ein netzweit eindeutiger Netzbereich. z.B. 104.1.2.1/28 Wenn das Feld leer bleibt wird ein Netzwerk automatisch nach den vorgaben aus dem Feld Freifunk Comunity erstellt")
			dhcpmesh:depends("client_" .. device, "1")
			dhcpmesh.rmempty = true
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
		if hwtype == "atheros" or ( hwtype == "mac80211" and has_hostapd ) then
			local vap = f:field(Flag, "vap_" .. device , "Virtueller Drahtloser Zugangspunkt", "Konfigurieren Sie Ihren Virtuellen AP")
			vap:depends("client_" .. device, "1")
			vap.rmempty = false
			function vap.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "vap_" .. device)
			end
			function vap.write(self, sec, value)
				uci:set("freifunk", "wizard", "vap_" .. device, value)
				uci:save("freifunk")
			end
			if has_ipv6 then
				dhcpip6 = f:field(Value, "dhcpip6_" .. device, device:upper() .. "  Mesh DHCP IPv6 Adresse einrichten", "Ihre Mesh IP Adresse wird automatisch berechnet")
				dhcpip6:depends("vap_" .. device, "1")
				dhcpip6.rmempty = true
				function dhcpip6.cfgvalue(self, section)
					return get_ula_rand(get_mac(device))
				end
			end

		end
	end)

uci:foreach("network", "interface",
	function(section)
		local device = section[".name"]
		local ifname = uci_state:get("network",device,"ifname")
		if device ~= "loopback" and not string.find(device, "tunl") and not string.find(device, "gvpn") and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			dev = f:field(Flag, "device_" .. device , "<b>Drahtgebundenes Freifunk Netzwerk \"" .. device:upper() .. "\"</b>", "Konfigurieren Sie Ihre drahtgebunde Schnittstelle: " .. device:upper() .. ".")
				dev.rmempty = false
				function dev.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "device_" .. device)
				end
				function dev.write(self, sec, value)
					uci:set("freifunk", "wizard", "device_" .. device, value)
					uci:save("freifunk")
				end
			meship = f:field(Value, "meship_" .. device, device:upper() .. "  Mesh IP Adresse einrichten", "Ihre Mesh IP Adresse erhalten Sie von der Freifunk Gemeinschaft in Ihrer Nachbarschaft. Es ist eine netzweit eindeutige Identifikation, z.B. 104.1.1.1.")
				meship:depends("device_" .. device, "1")
				meship.rmempty = true
				function meship.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "meship_" .. device)
				end
				function meship.validate(self, value)
					local x = ip.IPv4(value)
					return ( x and x:prefix() == 32 ) and x:string() or ""
				end
				function meship.write(self, sec, value)
					uci:set("freifunk", "wizard", "meship_" .. device, value)
				end
			if has_ipv6 then
				meship6 = f:field(Value, "meship6_" .. device, device:upper() .. "  Mesh IPv6 Adresse einrichten", "Ihre Mesh IP Adresse wird automatisch berechnet")
				meship6:depends("device_" .. device, "1")
				meship6.rmempty = true
				function meship6.cfgvalue(self, section)
					return get_ula(get_mac(ifname))
				end
			end

			client = f:field(Flag, "client_" .. device, device:upper() .. "  DHCP anbieten","DHCP weist verbundenen Benutzern automatisch eine Adresse zu. Diese Option sollten Sie unbedingt aktivieren, wenn Sie Nutzer an der drahtlosen Schnittstelle erwarten.")
				client:depends("device_" .. device, "1")
				client.rmempty = false
				function client.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "client_" .. device)
				end
				function client.write(self, sec, value)
					uci:set("freifunk", "wizard", "client_" .. device, value)
					uci:save("freifunk")
				end
			dhcpmesh = f:field(Value, "dhcpmesh_" .. device, device:upper() .. "  Mesh DHCP anbieten ", "Bestimmen Sie den Adressbereich aus dem Ihre Nutzer IP Adressen erhalten. Es wird empfohlen einen Adressbereich aus Ihrer lokalen Freifunk Gemeinschaft zu nutzen. Der Adressbereich ist ein netzweit eindeutiger Netzbereich. z.B. 104.1.2.1/28")
				dhcpmesh:depends("client_" .. device, "1")
				dhcpmesh.rmempty = true
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
		end
	end)


local syslat = uci:get("freifunk", "wizard", "latitude") or 52
local syslon = uci:get("freifunk", "wizard", "longitude") or 10
uci:foreach("system", "system", function(s)
		if s.latitude then
			syslat = s.latitude
		end
		if s.longitude then
			syslon = s.longitude
		end
end)
uci:foreach("olsrd", "LoadPlugin", function(s)
	if s.library == "olsrd_nameservice.so.0.3" then
		if s.lat then
			syslat = s.lat
		end
		if s.lon then
			syslon = s.lon
		end
	end
end)

lat = f:field(Value, "lat", "geographischer Breitengrad", "Setzen Sie den Breitengrad (Latitude) Ihres Geräts.")
function lat.cfgvalue(self, section)
	return syslat
end
function lat.write(self, section, value)
	uci:set("freifunk", "wizard", "latitude", value)
	uci:save("freifunk")
end

lon = f:field(Value, "lon", "geograpischer Längengrad", "Setzen Sie den Längengrad (Longitude) Ihres Geräts.")
function lon.cfgvalue(self, section)
	return syslon
end
function lon.write(self, section, value)
	uci:set("freifunk", "wizard", "longitude", value)
	uci:save("freifunk")
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
	self.template = "cbi/osmll_value"
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

osm = f:field(OpenStreetMapLonLat, "latlon", "Geokoordinaten mit OpenStreetMap ermitteln:", "Klicken Sie auf Ihren Standort in der Karte. Diese Karte funktioniert nur, wenn das Gerät bereits eine Verbindung zum Internet hat.")
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
	wanproto = f:field(ListValue, "wanproto", "<b>Internet WAN</b>", "Geben Sie das Protokol an ueber das eine Internet verbindung hergestellt werden kann.")
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
		if value == "3g" or value == "pppoe" then
			uci:set("network", "wan", "peerdns", "1")
			uci:set("network", "wan", "defaultroute", "1")
		end
		uci:save("network")
	end

	share = f:field(Flag, "sharenet", "Eigenen Internetzugang freigeben", "Geben Sie Ihren Internetzugang im Freifunknetz frei.")
	share.rmempty = false
	share:depends("device_wan", "")
	function share.cfgvalue(self, section)
		return uci:get("freifunk", "wizard", "share")
	end
	function share.write(self, section, value)
		uci:set("freifunk", "wizard", "share", value)
		uci:save("freifunk")
	end

	wanip = f:field(Value, "wanipaddr", translate("IPv4-Address"))
	wanip:depends("wanproto", "static")
	wanip.datatype = "ip4addr"
	function wanip.cfgvalue(self, section)
		return uci:get("network", "wan", "ipaddr")
	end
	function wanip.write(self, section, value)
		uci:set("network", "wan", "ipaddr", value)
		uci:save("network")
	end

	wannm = f:field(Value, "wannetmask", translate("IPv4-Netmask"))
	wannm:depends("wanproto", "static")
	wannm.datatype = "ip4addr"
	wannm:value("255.255.255.0")
	wannm:value("255.255.0.0")
	wannm:value("255.0.0.0")
	function wannm.cfgvalue(self, section)
		return uci:get("network", "wan", "netmask")
	end
	function wannm.write(self, section, value)
		uci:set("network", "wan", "netmask", value)
		uci:save("network")
	end

	wangw = f:field(Value, "wangateway", translate("IPv4-Gateway"))
	wangw:depends("wanproto", "static")
	wangw.datatype = "ip4addr"
	function wangw.cfgvalue(self, section)
		return uci:get("network", "wan", "gateway")
	end
	function wangw.write(self, section, value)
		uci:set("network", "wan", "gateway", value)
		uci:save("network")
	end
	function wangw.remove(self, section)
		uci:delete("network", "wan", "gateway")
		uci:save("network")
	end

	wandns = f:field(Value, "wandns", translate("DNS-Server"))
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

	wanusr = f:field(Value, "wanusername", translate("Username"))
	wanusr:depends("wanproto", "pppoe")
	wanusr.rmempty = true
	function wanusr.cfgvalue(self, section)
		return uci:get("network", "wan", "username")
	end
	function wanusr.write(self, section, value)
		uci:set("network", "wan", "username", value)
		uci:save("network")
	end

	wanpwd = f:field(Value, "wanpassword", translate("Password"))
	wanpwd.password = true
	wanpwd:depends("wanproto", "pppoe")
	wanpwd.rmempty = true
	function wanpwd.cfgvalue(self, section)
		return uci:get("network", "wan", "password")
	end
	function wanpwd.write(self, section, value)
		uci:set("network", "wan", "password", value)
		uci:save("network")
	end
	if has_firewall then
		wansec = f:field(Flag, "wansec", "WAN-Zugriff auf Gateway beschränken", "Verbieten Sie Zugriffe auf Ihr lokales Netzwerk aus dem Freifunknetz.")
		wansec.rmempty = false
		wansec:depends("sharenet", "1")
		function wansec.cfgvalue(self, section)
			return uci:get("freifunk", "wizard", "wan_security")
		end
		function wansec.write(self, section, value)
			uci:set("freifunk", "wizard", "wan_security", value)
			uci:save("freifunk")
		end
	end
	if has_3g or has_pppoe then
		wandevice = f:field(Value, "device",
		 translate("Modem device"),
		 translate("The device node of your modem, e.g. /dev/ttyUSB0")
		)
		wandevice:value("/dev/ttyUSB0")
		wandevice:depends("wanproto", "ppp")
		wandevice:depends("wanproto", "3g")
		function wandevice.cfgvalue(self, section)
			return uci:get("network", "wan", "device")
		end
		function wandevice.write(self, section, value)
			uci:set("network", "wan", "device", value)
			uci:save("network")
		end
	end
	if has_3g then
		service = f:field(ListValue, "service", translate("Service type"))
		service:value("", translate("-- Please choose --"))
		service:value("umts", "UMTS/GPRS")
		service:value("cdma", "CDMA")
		service:value("evdo", "EV-DO")
		service:depends("wanproto", "3g")
		service.rmempty = true
		function service.cfgvalue(self, section)
			return uci:get("network", "wan", "service")
		end
		function service.write(self, section, value)
			uci:set("network", "wan", "service", value)
			uci:save("network")
		end

		apn = f:field(Value, "apn", translate("Access point (APN)"))
		apn:depends("wanproto", "3g")
		function apn.cfgvalue(self, section)
			return uci:get("network", "wan", "apn")
		end
		function apn.write(self, section, value)
			uci:set("network", "wan", "apn", value)
			uci:save("network")
		end

		pincode = f:field(Value, "pincode",
		 translate("PIN code"),
		 translate("Make sure that you provide the correct pin code here or you might lock your sim card!")
		)
		pincode:depends("wanproto", "3g")
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
	sharelan = f:field(Flag, "sharelan", "Eigenen Internetzugang freigeben", "Geben Sie Ihren Internetzugang ueber LAN frei.")
	sharelan.rmempty = false
	sharelan:depends("lanproto", "static")
	sharelan:depends("lanproto", "dhcp")
	function sharelan.cfgvalue(self, section)
		return uci:get("freifunk", "wizard", "sharelan")
	end
	function sharelan.write(self, section, value)
		uci:set("freifunk", "wizard", "sharelan", value)
		uci:save("freifunk")
	end
	lanip = f:field(Value, "lanipaddr", translate("IPv4-Address"))
	lanip:depends("lanproto", "static")
	function lanip.cfgvalue(self, section)
		return uci:get("network", "lan", "ipaddr")
	end
	function lanip.write(self, section, value)
		uci:set("network", "lan", "ipaddr", value)
		uci:save("network")
	end
	lannm = f:field(Value, "lannetmask", translate("IPv4-Netmask"))
	lannm:depends("lanproto", "static")
	function lannm.cfgvalue(self, section)
		return uci:get("network", "lan", "netmask")
	end
	function lannm.write(self, section, value)
		uci:set("network", "lan", "netmask", value)
		uci:save("network")
	end
	langw = f:field(Value, "langateway", translate("IPv4-Gateway"))
	langw:depends("lanproto", "static")
	langw.rmempty = true
	function langw.cfgvalue(self, section)
		return uci:get("network", "lan", "gateway")
	end
	function langw.write(self, section, value)
		uci:set("network", "lan", "gateway", value)
		uci:save("network")
	end
	function langw.remove(self, section)
		uci:delete("network", "lan", "gateway")
		uci:save("network")
	end
	landns = f:field(Value, "landns", translate("DNS-Server"))
	landns:depends("lanproto", "static")
	function landns.cfgvalue(self, section)
		return uci:get("network", "lan", "dns")
	end
	function landns.write(self, section, value)
		uci:set("network", "lan", "dns", value)
		uci:save("network")
	end
	if has_firewall then
		lansec = f:field(Flag, "lansec", "LAN-Zugriff auf Gateway beschränken", "Verbieten Sie Zugriffe auf Ihr lokales Netzwerk aus dem Freifunknetz.")
		lansec.rmempty = false
		lansec:depends("sharelan", "1")
		function lansec.cfgvalue(self, section)
			return uci:get("freifunk", "wizard", "lan_security")
		end
	end
	if has_qos then
		lanqosdown = f:field(Value, "lanqosdown", "Download Bandbreite begrenzen", "kb/s")
		lanqosdown:depends("sharelan", "1")
		function lanqosdown.cfgvalue(self, section)
			return uci:get("qos", "lan", "download")
		end
		function lanqosdown.write(self, section, value)
			uci:set("qos", "lan", "download", value)
			uci:save("qos")
		end
		function lanqosdown.remove(self, section)
			uci:delete("qos", "lan", "download")
			uci:save("qos")
		end
		lanqosup = f:field(Value, "lanqosup", "Upload Bandbreite begrenzen", "kb/s")
		lanqosup:depends("sharelan", "1")
		function lanqosup.cfgvalue(self, section)
			return uci:get("qos", "lan", "upload")
		end
		function lanqosup.write(self, section, value)
			uci:set("qos", "lan", "upload", value)
			uci:save("qos")
		end
		function lanqosup.remove(self, section)
			uci:delete("qos", "lan", "upload")
			uci:save("qos")
		end
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
	gvpnip = f:field(Value, "gvpnipaddr", translate("IPv4-Address"))
	gvpnip:depends("gvpn", "1")
	function gvpnip.cfgvalue(self, section)
		return uci:get("l2gvpn", "bbb", "ip") or uci:get("network", "gvpn", "ipaddr")
	end
	function gvpnip.validate(self, value)
		local x = ip.IPv4(value)
		return ( x and x:prefix() == 32 ) and x:string() or ""
	end
end


if has_hb then
	hb = f:field(Flag, "hb", "Heartbeat aktivieren","Dem Gerät erlauben anonyme Statistiken zu übertragen. (empfohlen)")
	hb.rmempty = false
	function hb.cfgvalue(self, section)
		return uci:get("freifunk", "wizard", "hb")
	end
	function hb.write(self, section, value)
		uci:set("freifunk", "wizard", "hb", value)
		uci:save("freifunk")
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
			luci.http.redirect(luci.dispatcher.build_url("mini", "system"))
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
				uci:commit("luci_splash")
				uci:commit("firewall")
				uci:commit("freifunk_p2pblock")
			end
			uci:commit("system")
			uci:commit("uhttpd")
			uci:commit("olsrd")
			uci:commit("manager")
			if has_autoipv6 then
				uci:commit("autoipv6")
			end
			if has_qos then
				uci:commit("qos")
			end
			if has_l2gvpn then
				uci:commit("l2gvpn")
			end
			if has_radvd then
				uci:commit("radvd")
			end
-- the following line didn't work without admin-mini, for now i just replaced it with sys.exec... soma
			luci.http.redirect(luci.dispatcher.build_url("mini", "system", "reboot") .. "?reboot=1")
--			sys.exec("reboot")
		end
		return false
	elseif state == FORM_INVALID then
		self.errmessage = "Ungültige Eingabe: Bitte die Formularfelder auf Fehler prüfen."
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
	local community = net:formvalue(section)
	suffix = uci:get_first("profile_"..community, "community", "suffix") or "olsr"
	
	-- Invalidate fields
	if not community then
		net.tag_missing[section] = true
		return
	end

	local external
	external = "profile_"..community

	local netname = "wireless"
	local network
	network = ip.IPv4(uci:get_first("profile_"..community, "community", "mesh_network") or "104.0.0.0/8")

	-- Tune community settings
	if community and uci:get("profile_"..community, "profile") then
		uci:tset("freifunk", "community", uci:get_all("profile_"..community, "profile"))
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
	if has_hb then
		uci:delete("manager", "heartbeat", "interface")
		uci:save("manager")
	end

	-- Delete olsrdv4
	uci:delete_all("olsrd", "olsrd")
	local olsrbase = uci:get_all("freifunk", "olsrd") or {}
	util.update(olsrbase, uci:get_all(external, "olsrd") or {})
	if has_ipv6 then
		olsrbase.IpVersion='6and4'
	else
		olsrbase.IpVersion='4'
	end

	-- Internet sharing
	local share_value = 0
	local sharelan_value = 0
	if has_wan then
		share_value = share:formvalue(section) or 0
		uci:set("freifunk", "wizard", "share_value", share_value)
	end
	if has_lan then
		sharelan_value = sharelan:formvalue(section) or 0
		uci:set("freifunk", "wizard", "sharelan_value", sharelan_value)
	end
	if share_value == "1" then
		olsrbase.SmartGateway="yes"
		if has_qos then
			qosd=wanqosdown:formvalue(section)
			qosu=wanqosup:formvalue(section)
			if (qosd and qosd ~= "") and (qosu and qosd ~= "")  then
				olsrbase.SmartGatewaySpeed=qosu.." "..qosd
			else
				olsrbase.SmartGatewaySpeed="500 10000"
			end
		end
	end
	if sharelan_value == "1" then
		olsrbase.SmartGateway="yes"
		if has_qos then
			qosd=lanqosdown:formvalue(section)
			qosu=lanqosup:formvalue(section)
			if (qosd and qosd ~= "") and (qosu and qosd ~= "")  then
				olsrbase.SmartGatewaySpeed=qosu.." "..qosd
			else
				olsrbase.SmartGatewaySpeed="500 10000"
			end
		end
	end
	
	if share_value == "1" or sharelan_value == "1" then
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

	-- Read Preset for lan and wan
	local radvd_if
	local radvd_pre
	local radvd_rdnss
	local radvd_dnssl
	if has_radvd then
		radvd_if = uci:get_all("freifunk", "radvd_interface") or 0
		radvd_pre = uci:get_all("freifunk", "radvd_prefix") or 0
		radvd_rdnss = uci:get_all("freifunk", "radvd_rdnss") or 0
		radvd_dnssl = uci:get_all("freifunk", "radvd_dnssl") or 0
		if radvd_if == 0 or radvd_pre == 0 or radvd_rdnss == 0 or radvd_dnssl == 0 then
			has_radvd = nil
		end
	end

	-- Create wireless ip4/ip6 and firewall config
	uci:foreach("wireless", "wifi-device",
	function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
		if has_ipv6 then
			node_ip6 = luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device) and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device))
			dhcp_ip6 = luci.http.formvalue("cbid.ffwizward.1.dhcpip6_" .. device) and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.dhcpip6_" .. device))
		end
		if not node_ip or not network or not network:contains(node_ip) then
			meship.tag_missing[section] = true
			node_ip = nil
			return
		end
		-- rename the wireless interface s/wifi/wireless/
		local nif
		if string.find(device, "wifi") then
			nif = string.gsub(device,"wifi", netname)
		elseif string.find(device, "wl") then
			nif = string.gsub(device,"wl", netname)
		elseif string.find(device, "wlan") then
			nif = string.gsub(device,"wlan", netname)
		elseif string.find(device, "radio") then
			nif = string.gsub(device,"radio", netname)
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
		-- Delete old radvd
		if has_radvd then
			uci:delete_all("radvd", "interface", {interface=nif.."dhcp"})
			uci:delete_all("radvd", "interface", {interface=nif})
			uci:delete_all("radvd", "prefix", {interface=nif.."dhcp"})
			uci:delete_all("radvd", "prefix", {interface=nif})
			uci:delete_all("radvd", "rdnss", {interface=nif.."dhcp"})
			uci:delete_all("radvd", "rdnss", {interface=nif})
			uci:delete_all("radvd", "dnssl", {interface=nif.."dhcp"})
			uci:delete_all("radvd", "dnssl", {interface=nif})
		end
		-- New Config
		-- Tune wifi device
		local ssid = uci:get_first("profile_"..community, "community", "ssid")
		local ssiddot = string.find(ssid,'%..*')
		local ssidshort
		if ssiddot then
			ssidshort = string.sub(ssid,ssiddot)
		else
			ssidshort = ssid
		end
		local devconfig = uci:get_all("freifunk", "wifi_device") or {}
		util.update(devconfig, uci:get_all(external, "wifi_device") or {})
		local channel = luci.http.formvalue("cbid.ffwizward.1.chan_" .. device)
		local hwtype = sec.type
		local hwmode
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
		local chan
		if channel then
			if channel == "default" then
				channel = devconfig.channel
				chan = tonumber(channel)
				if chan > 0 and chan < 14 then
					hwmode = hwmode.."g"
				elseif chan >= 36 and chan <= 64 then
					hwmode = hwmode.."a"
					mrate = ""
					outdoor = 0
				elseif chan >= 100 and chan <= 140 then
					hwmode = hwmode.."a"
					mrate = ""
					outdoor = 1
				end
			else
				devconfig.channel = channel
				chan = tonumber(channel)
				if chan > 0 and chan < 10 then
					hwmode = hwmode.."g"
					bssid = channel .. "2:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan == 10 then
					hwmode = hwmode.."g"
					bssid = "02:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 11 and chan <= 14 then
					hwmode = hwmode.."g"
					bssid = string.format("%X",channel) .. "2:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 36 and chan <= 64 then
					hwmode = hwmode.."a"
					mrate = ""
					outdoor = 0
					bssid = "00:" .. channel ..":CA:FF:EE:EE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 100 and chan <= 140 then
					hwmode = hwmode.."a"
					mrate = ""
					outdoor = 1
					bssid = "01:" .. string.sub(channel, 2) .. ":CA:FF:EE:EE"
					ssid = "ch" .. channel .. ssidshort
				end
			end
			devconfig.hwmode = hwmode
			devconfig.outdoor = outdoor
		end
		if has_n then
			if chan > 0 and chan < 5 and devconfig.htmode == 'HT40-' then
				devconfig.htmode = 'HT40+'
			elseif chan > 9 and chan < 14 and devconfig.htmode == 'HT40+' then
				devconfig.htmode = 'HT40-'
			elseif chan == 36 and devconfig.htmode == 'HT40-' then
				devconfig.htmode = 'HT40+'
			elseif chan == 64 and devconfig.htmode == 'HT40+' then
				devconfig.htmode = 'HT40-'
			elseif chan == 100 and devconfig.htmode == 'HT40-' then
				devconfig.htmode = 'HT40+'
			elseif chan == 136 and devconfig.htmode == 'HT40+' then
				devconfig.htmode = 'HT40-'
			elseif chan == 140 then
				devconfig.htmode = 'HT20'
			end
		end
		local advanced = luci.http.formvalue("cbid.ffwizward.1.advanced_" .. device)
		if advanced then
			local hwmode = luci.http.formvalue("cbid.ffwizward.1.hwmode_" .. device)
			if hwmode then
				devconfig.hwmode = hwmode
			end
			local htmode = luci.http.formvalue("cbid.ffwizward.1.htmode_" .. device)
			if htmode then
				devconfig.htmode = htmode
			end
			local txpower = luci.http.formvalue("cbid.ffwizward.1.txpower_" .. device)
			if txpower then
				devconfig.txpower = txpower
			end
			local distance = luci.http.formvalue("cbid.ffwizward.1.distance_" .. device)
			if distance then
				devconfig.distance = distance
			end
			local txantenna = luci.http.formvalue("cbid.ffwizward.1.txantenna_" .. device)
			if txantenna then
				devconfig.txantenna = txantenna
			end
			local rxantenna = luci.http.formvalue("cbid.ffwizward.1.rxantenna_" .. device)
			if rxantenna then
				devconfig.rxantenna = rxantenna
			end
		end
		uci:tset("wireless", device, devconfig)
		-- Create wifi iface
		local ifconfig = uci:get_all("freifunk", "wifi_iface")
		util.update(ifconfig, uci:get_all(external, "wifi_iface") or {})
		ifconfig.device = device
		ifconfig.network = nif
		if ssid then
			-- See Table https://kifuse02.pberg.freifunk.net/moin/channel-bssid-essid 
			ifconfig.ssid = ssid
		else
			ifconfig.ssid = "olsr.freifunk.net"
		end
		-- See Table https://kifuse02.pberg.freifunk.net/moin/channel-bssid-essid
		if bssid then
			ifconfig.bssid = bssid
		end
		ifconfig.encryption="none"
		-- Read Preset 
		local prenetconfig = uci:get_all("freifunk", "interface") or {}
		util.update(prenetconfig, uci:get_all(external, "interface") or {})
		prenetconfig.proto = "static"
		prenetconfig.ipaddr = node_ip:string()
		if has_ipv6 then
			if node_ip6 then
				prenetconfig.ip6addr = node_ip6:string()
			end
		end
		uci:section("network", "interface", nif, prenetconfig)
		if has_radvd then
			radvd_if.interface=nif
			radvd_pre.interface=nif
			radvd_rdnss.interface=nif
			radvd_dnssl.interface=nif
			uci:section("radvd", "interface", nil, radvd_if)
			uci:section("radvd", "prefix", nil, radvd_pre)
			uci:section("radvd", "rdnss", nil, radvd_rdnss)
			uci:section("radvd", "dnssl", nil, radvd_dnssl)
			uci:save("radvd")
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
		local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
		if client then
			local dhcpmeshnet = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
			if has_hb then
				local ifacelist = uci:get_list("manager", "heartbeat", "interface") or {}
				table.insert(ifacelist,nif .. "dhcp")
				uci:set_list("manager", "heartbeat", "interface", ifacelist)
				uci:save("manager")
			end
			if dhcpmeshnet then
				if not dhcpmeshnet:minhost() or not dhcpmeshnet:mask() then
					dhcpmesh.tag_missing[section] = true
					dhcpmeshnet = nil
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
							uci:set("olsrd", s['.name'], "ignore", "0")
							local nonolsr = uci:get_list("olsrd", s['.name'], "NonOlsrIf") or {}
							vap = luci.http.formvalue("cbid.ffwizward.1.vap_" .. device)
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
				vap = luci.http.formvalue("cbid.ffwizward.1.vap_" .. device)
				if vap then
					if has_ipv6 then
						if dhcp_ip6 then
							aliasbase.ip6addr = dhcp_ip6:string()
							dhcpnetaddr = dhcp_ip6:network(64):string()
							uci:section("olsrd", "Hna6", nil, {
								prefix = 64,
								netaddr = dhcpnetaddr
							})
							uci:save("olsrd")
						end
					end
					uci:section("network", "interface", nif .. "dhcp", aliasbase)
					uci:section("wireless", "wifi-iface", nil, {
						device     =device,
						mode       ="ap",
						encryption ="none",
						network    =nif.."dhcp",
						ssid       ="AP"..channel..ssidshort
					})
					if has_radvd then
						radvd_if.interface=nif .. "dhcp"
						radvd_pre.interface=nif .. "dhcp"
						radvd_rdnss.interface=nif .. "dhcp"
						radvd_dnssl.interface=nif .. "dhcp"
						uci:section("radvd", "interface", nil, radvd_if)
						uci:section("radvd", "prefix", nil, radvd_pre)
						uci:section("radvd", "rdnss", nil, radvd_rdnss)
						uci:section("radvd", "dnssl", nil, radvd_dnssl)
						uci:save("radvd")
					end
					if has_firewall then
						tools.firewall_zone_add_interface("freifunk", nif .. "dhcp")
					end
					uci:save("wireless")
					ifconfig.mcast_rate = nil
					ifconfig.encryption="none"
				else
					aliasbase.interface = nif
					uci:section("network", "alias", nif .. "dhcp", aliasbase)
				end
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
					-- Register splash
					uci:section("luci_splash", "iface", nil, {network=nif.."dhcp", zone="freifunk"})
					uci:save("luci_splash")
					-- Make sure that luci_splash is enabled
					sys.init.enable("luci_splash")
				end
			end
		else
			if has_firewall then
				-- Delete old splash
				uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
			end
		end
		--Write Ad-Hoc wifi section after AP wifi section
		uci:section("wireless", "wifi-iface", nil, ifconfig)
		uci:save("network")
		uci:save("wireless")
		uci:save("network")
		if has_firewall then
			uci:save("firewall")
		end
		uci:save("dhcp")
	end)
	-- Create wired ip and firewall config
	uci:foreach("network", "interface",
		function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		if device ~= "loopback" and not string.find(device, "tunl") and not string.find(device, "gvpn") and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			local node_ip
			node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
			if has_ipv6 then
				node_ip6 = luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device) and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device))
			end
			if not node_ip or not network or not network:contains(node_ip) then
				meship.tag_missing[section] = true
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
			if has_firewall then
				-- Delete old splash
				uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
			end
			if has_radvd then
				uci:delete_all("radvd", "interface", {interface=device})
				uci:delete_all("radvd", "prefix", {interface=device})
				uci:delete_all("radvd", "rdnss", {interface=device})
				uci:delete_all("radvd", "dnssl", {interface=device})
			end
			-- New Config
			local prenetconfig = uci:get_all("freifunk", "interface") or {}
			util.update(prenetconfig, uci:get_all(external, "interface") or {})
			prenetconfig.proto = "static"
			prenetconfig.ipaddr = node_ip:string()
			prenetconfig.gateway = ''
			prenetconfig.username = ''
			prenetconfig.password = ''
			if has_ipv6 then
				if node_ip6 then
					prenetconfig.ip6addr = node_ip6:string()
				end
			end
			uci:section("network", "interface", device, prenetconfig)
			uci:save("network")
			if has_wan and device == "wan" then
				has_wan=nil
				share_value=0
			end
			if has_lan and device == "lan" then
				has_lan=nil
				sharelan_value=0
			end
			if has_radvd then
				radvd_if.interface=device
				radvd_pre.interface=device
				radvd_rdnss.interface=device
				radvd_dnssl.interface=device
				uci:section("radvd", "interface", nil, radvd_if)
				uci:section("radvd", "prefix", nil, radvd_pre)
				uci:section("radvd", "rdnss", nil, radvd_rdnss)
				uci:section("radvd", "dnssl", nil, radvd_dnssl)
				uci:save("radvd")
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
			local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
			if client then
				local dhcpmeshnet = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
				if has_hb then
					local ifacelist = uci:get_list("manager", "heartbeat", "interface") or {}
					table.insert(ifacelist,device .. "dhcp")
					uci:set_list("manager", "heartbeat", "interface", ifacelist)
					uci:save("manager")
				end
				if dhcpmeshnet then
					if not dhcpmeshnet:minhost() or not dhcpmeshnet:mask() then
						dhcpmesh.tag_missing[section] = true
						dhcpmeshnet = nil
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
								uci:set("olsrd", s['.name'], "ignore", "0")
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
					aliasbase.interface = device
					aliasbase.ipaddr = dhcp_ip
					aliasbase.netmask = dhcp_mask
					aliasbase.proto = "static"
					uci:section("network", "alias", device .. "dhcp", aliasbase)
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
						uci:section("luci_splash", "iface", nil, {network=device.."dhcp", zone="freifunk"})
						uci:save("luci_splash")
						-- Make sure that luci_splash is enabled
						sys.init.enable("luci_splash")
					end
				end
			end
			uci:save("wireless")
			uci:save("network")
			if has_firewall then
				uci:save("firewall")
			end
			uci:save("dhcp")
		end
	end)
	--enable radvd
	if has_radvd then
		sys.init.enable("radvd")
	end
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
	end
	uci:save("wireless")
	uci:save("network")
	uci:save("dhcp")

	local new_hostname = uci:get("freifunk", "wizard", "hostname")
	local old_hostname = sys.hostname()
	local custom_hostname = hostname:formvalue(section)

	if has_hb then
		local dhcphb = hb:formvalue(section)
		if dhcphb then
			uci:set("manager", "heartbeat", "enabled", "1")
			-- Make sure that heartbeat is enabled
			sys.init.enable("machash")
		else
			uci:set("manager", "heartbeat", "enabled", "0")
			-- Make sure that heartbeat is enabled
			sys.init.disable("machash")
		end
		uci:save("manager")
		local nid = nodeid:formvalue(section)
		if nid then
			uci:foreach("system", "system", function(s)
				uci:set("system", s[".name"], "nodeid",nid)
			end)
		end
		uci:save("system")
	end

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
		hosts_file  = "/var/etc/hosts.olsr",
		latlon_file = "/var/run/latlon.js",
		lat         = latval and string.format("%.15f", latval) or "",
		lon         = lonval and string.format("%.15f", lonval) or "",
		services_file = "/var/etc/services.olsr"
	})

	-- Import hosts and set domain
	uci:foreach("dhcp", "dnsmasq", function(s)
		uci:set_list("dhcp", s[".name"], "addnhosts", "/var/etc/hosts.olsr")
		uci:set("dhcp", s[".name"], "local", "/" .. suffix .. "/")
		uci:set("dhcp", s[".name"], "domain", suffix)
	end)

	-- Make sure that OLSR is enabled
	sys.init.enable("olsrd")

	uci:save("olsrd")
	uci:save("dhcp")
	-- Import hosts and set domain
	if has_ipv6 then
	        uci:foreach("dhcp", "dnsmasq", function(s)
	                uci:set_list("dhcp", s[".name"], "addnhosts", {"/var/etc/hosts.olsr","/var/etc/hosts.olsr.ipv6"})
	        end)
	else
	        uci:foreach("dhcp", "dnsmasq", function(s)
	                uci:set_list("dhcp", s[".name"], "addnhosts", "/var/etc/hosts.olsr")
        	end)
	end

	uci:save("dhcp")

	local wproto
	if has_wan then
		if has_radvd then
				uci:delete_all("radvd", "interface", {interface='wan'})
				uci:delete_all("radvd", "prefix", {interface='wan'})
				uci:delete_all("radvd", "rdnss", {interface='wan'})
				uci:delete_all("radvd", "dnssl", {interface='wan'})
				uci:save("radvd")
		end
		wproto = wanproto:formvalue(section)
		if wproto == "static" then
			local fwanip=wanip:formvalue(section)
			local fwannm=wannm:formvalue(section)
			local fwanipn=ip.IPv4(fwanip,flannm)
			if has_firewall then
				tools.firewall_zone_add_masq_src("freifunk", fwanipn:string())
				tools.firewall_zone_enable_masq("freifunk")
				uci:save("firewall")
			end
		end
	end
	local lproto
	if has_lan then
		if has_radvd then
				uci:delete_all("radvd", "interface", {interface='lan'})
				uci:delete_all("radvd", "prefix", {interface='lan'})
				uci:delete_all("radvd", "rdnss", {interface='lan'})
				uci:delete_all("radvd", "dnssl", {interface='lan'})
				uci:save("radvd")
		end
		-- Delete old dhcp
		uci:delete("dhcp", "lan")
		lproto = lanproto:formvalue(section)
		if lproto == "static" then
			local flanip=lanip:formvalue(section)
			local flannm=lannm:formvalue(section)
			local flanipn=ip.IPv4(flanip,flannm)
			if has_firewall then
				tools.firewall_zone_add_masq_src("freifunk", flanipn:string())
				tools.firewall_zone_enable_masq("freifunk")
				uci:save("firewall")
			end
			-- Create dhcp
			local dhcpbase = {}
			dhcpbase.interface = "lan"
			dhcpbase.ignore = 0
			uci:section("dhcp", "dhcp", "lan", dhcpbase)
			uci:set_list("dhcp", "lan", "dhcp_option", {"119,lan","119,olsr"})
			uci:save("dhcp")
		end
	end

	if share_value == "1" or sharelan_value == "1" then
		uci:set("freifunk", "wizard", "shareconfig", "1")
		uci:save("freifunk")
		if has_autoipv6 then
			-- Set autoipv6 tunnel mode
			uci:set("autoipv6", "olsr_node", "enable", "0")
			uci:set("autoipv6", "tunnel", "enable", "1")
			uci:save("autoipv6")
			-- Create tun6to4 interface
			local tun6to4 = {}
			tun6to4.ifname = "tun6to4"
			tun6to4.proto = "none"
			uci:section("network", "interface", "6to4", tun6to4)
			uci:save("network")
		end

		-- Delete/Disable gateway plugin
		uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})
		uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
		-- Enable gateway_plain plugin
		uci:section("olsrd", "LoadPlugin", nil, {library="olsrd_dyn_gw_plain.so.0.4"})
		if has_firewall then
			sys.exec("chmod +x /etc/init.d/freifunk-p2pblock")
			sys.init.enable("freifunk-p2pblock")
		end
		if has_qos then
			sys.init.enable("qos")
		end
		

		if share_value == "1" then
			if has_qos then
				uci:delete("qos","wan")
				uci:delete("qos","lan")
				uci:section("qos", 'interface', "wan", {
					enabled     = "1",
					classgroup  = "Default",
				})
				uci:save("qos")
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
				if has_autoipv6 then
					tools.firewall_zone_add_interface("wan", "6to4")
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
			end
			sys.exec('grep wan /etc/crontabs/root >/dev/null || echo "0 6 * * * 	ifup wan" >> /etc/crontabs/root')
		else
			if has_qos then
				uci:set("qos", "wan", "enabled", "0")
				uci:save("qos")
			end
			if has_radvd and wproto == "static" then
				radvd_if.interface='wan'
				radvd_pre.interface='wan'
				radvd_rdnss.interface='wan'
				radvd_dnssl.interface='wan'
				uci:section("radvd", "interface", nil, radvd_if)
				uci:section("radvd", "prefix", nil, radvd_pre)
				uci:section("radvd", "rdnss", nil, radvd_rdnss)
				uci:section("radvd", "dnssl", nil, radvd_dnssl)
				uci:save("radvd")
			end
		end
		if sharelan_value == "1" then
			if has_qos then
				uci:delete("qos","wan")
				uci:delete("qos","lan")
				uci:section("qos", 'interface', "lan", {
					enabled     = "1",
					classgroup  = "Default",
				})
				uci:save("qos")
			end
			if has_firewall then
				uci:set("freifunk_p2pblock", "p2pblock", "interface", "lan")
				uci:save("freifunk_p2pblock")
				uci:delete_all("firewall","zone", {name="lan"})
				uci:section("firewall", "zone", nil, {
					masq	= "1",
					input   = "ACCEPT",
					forward = "ACCEPT",
					name    = "lan",
					output  = "ACCEPT",
					network = "lan"
				})
				uci:delete_all("firewall","forwarding", {src="freifunk", dest="lan"})
				uci:section("firewall", "forwarding", nil, {src="freifunk", dest="lan"})
				uci:delete_all("firewall","forwarding", {src="lan", dest="freifunk"})
				uci:section("firewall", "forwarding", nil, {src="lan", dest="freifunk"})
				uci:delete_all("firewall","forwarding", {src="lan", dest="wan"})
				uci:section("firewall", "forwarding", nil, {src="lan", dest="wan"})
				if has_autoipv6 then
					tools.firewall_zone_add_interface("lan", "6to4")
				end
				uci:save("firewall")
				if lansec:formvalue(section) == "1" then
					uci:foreach("firewall", "zone",
						function(s)		
							if s.name == "lan" then
								uci:set("firewall", s['.name'], "local_restrict", "1")
								uci:set("firewall", s['.name'], "masq", "1")
								uci:save("firewall")
								return false
							end
						end)
				end
			end
		else
			if has_qos then
				uci:set("qos", "lan", "enabled", "0")
				uci:save("qos")
			end
			if has_radvd and lproto == "static" then
				radvd_if.interface='lan'
				radvd_pre.interface='lan'
				radvd_rdnss.interface='lan'
				radvd_dnssl.interface='lan'
				uci:section("radvd", "interface", nil, radvd_if)
				uci:section("radvd", "prefix", nil, radvd_pre)
				uci:section("radvd", "rdnss", nil, radvd_rdnss)
				uci:section("radvd", "dnssl", nil, radvd_dnssl)
				uci:save("radvd")
			end
		end
	else
		uci:set("freifunk", "wizard", "shareconfig", "0")
		uci:save("freifunk")
		if has_autoipv6 then
			-- Set autoipv6 olsrd mode
			uci:set("autoipv6", "olsr_node", "enable", "1")
			uci:set("autoipv6", "tunnel", "enable", "0")
			uci:save("autoipv6")
		end
		-- Delete gateway plugins
		uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})
		uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
		-- Disable gateway_plain plugin
		uci:section("olsrd", "LoadPlugin", nil, {
			library     = "olsrd_dyn_gw_plain.so.0.4",
			ignore      = 1,
		})
--		if has_qos then
--			sys.init.disable("qos")
--		end
		if has_firewall then
			sys.init.disable("freifunk-p2pblock")
			sys.exec("chmod -x /etc/init.d/freifunk-p2pblock")
			uci:delete_all("firewall", "forwarding", {src="freifunk", dest="wan"})
			uci:foreach("firewall", "zone",
				function(s)		
					if s.name == "wan" or s.name == "lan" then
						uci:delete("firewall", s['.name'], "local_restrict")
						return false
					end
				end)
		end
		if has_radvd and wproto == "static" then
			radvd_if.interface='wan'
			radvd_pre.interface='wan'
			radvd_rdnss.interface='wan'
			radvd_dnssl.interface='wan'
			uci:section("radvd", "interface", nil, radvd_if)
			uci:section("radvd", "prefix", nil, radvd_pre)
			uci:section("radvd", "rdnss", nil, radvd_rdnss)
			uci:section("radvd", "dnssl", nil, radvd_dnssl)
			uci:save("radvd")
		end
		if has_radvd and lproto == "static" then
			radvd_if.interface='lan'
			radvd_pre.interface='lan'
			radvd_rdnss.interface='lan'
			radvd_dnssl.interface='lan'
			uci:section("radvd", "interface", nil, radvd_if)
			uci:section("radvd", "prefix", nil, radvd_pre)
			uci:section("radvd", "rdnss", nil, radvd_rdnss)
			uci:section("radvd", "dnssl", nil, radvd_dnssl)
			uci:save("radvd")
		end
	end
	-- Write gvpn dummy interface
	if has_l2gvpn then
		if gvpn then
			local vpn = gvpn:formvalue(section)
			if vpn then
				uci:delete_all("l2gvpn", "l2gvpn")
				uci:delete_all("l2gvpn", "node")
				uci:delete_all("l2gvpn", "supernode")
				-- Write olsr tunnel interface options
				local olsr_gvpnifbase = uci:get_all("freifunk", "olsr_gvpninterface") or {}
				util.update(olsr_gvpnifbase, uci:get_all(external, "olsr_gvpninterface") or {})
				uci:section("olsrd", "Interface", nil, olsr_gvpnifbase)
				local vpnip = gvpnip:formvalue(section) and ip.IPv4(gvpnip:formvalue(section))
				if not vpnip then
					vpnip.tag_missing[section] = true
					vpnip = nil
					return
				end
				local vpn_ip = vpnip:string()
				local gvpnif = uci:get_all("freifunk", "gvpn_node") or {}
				util.update(gvpnif, uci:get_all(external, "gvpn_node") or {})
				if gvpnif and gvpnif.tundev and vpnip then
					uci:section("network", "interface", gvpnif.tundev, {
						ifname  =gvpnif.tundev ,
						proto   ="static" ,
						ipaddr  =vpnip:string() ,
						netmask =gvpnif.subnet or "255.255.255.192" ,
					})
					gvpnif.ip=""
					gvpnif.subnet=""
					gvpnif.up=""
					gvpnif.down=""
					gvpnif.mac="00:00:48:"..string.format("%X",string.gsub(vpnip:string(), ".*%." , "" ))..":00:00"
					if has_firewall then
						tools.firewall_zone_add_interface("freifunk", gvpnif.tundev)
						uci:delete_all("firewall", "rule", {
							src       ="wan",
							proto     ="udp",
							dest_port =gvpnif.localport or "8719",
							target    ="ACCEPT"
						})
						uci:section("firewall", "rule", nil, {
							src       ="wan",
							proto     ="udp",
							dest_port =gvpnif.localport or "8719",
							target    ="ACCEPT"
						})
						uci:save("firewall")
					end
					uci:section("l2gvpn", "node" , gvpnif.community , gvpnif)
					uci:save("network")
					uci:save("l2gvpn")
					uci:save("olsrd")
					sys.init.enable("l2gvpn")
				end
			else
				-- Disable l2gvpn
				sys.exec("/etc/init.d/l2gvpn stop")
				sys.init.disable("l2gvpn")
			end
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

