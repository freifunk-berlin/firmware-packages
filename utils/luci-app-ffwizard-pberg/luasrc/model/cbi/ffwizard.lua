--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>
Copyright 2010 Patrick Grimm <patrick@pberg.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id$

]]--


local uci = require "luci.model.uci".cursor()
local tools = require "luci.tools.ffwizard"
local util = require "luci.util"
local sys = require "luci.sys"
local ip = require "luci.ip"

-------------------- View --------------------
f = SimpleForm("ffwizward", "Freifunkassistent",
 "Dieser Assistent unterstüzt bei der Einrichtung des Routers für das Freifunknetz.")

net = f:field(ListValue, "net", "Freifunk Community", "Mesh WLAN Netzbereich")
net.rmempty = false
net.optional = false
uci:foreach("freifunk", "community", function(s)
	net:value(s[".name"], "%s (%s)" % {s.name, s.mesh_network or "?"})
end)
function net.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "net")
end
function net.write(self, section, value)
	uci:set("freifunk", "wizard", "net", value)
	uci:save("freifunk")
end

main = f:field(Flag, "netconfig", "=== Netzwerk einrichten ===")
uci:foreach("wireless", "wifi-device",
	function(section)
		local device = section[".name"]
		local dev = f:field(Flag, "device_" .. device , " === Drahtloses Netzwerk \"" .. device:upper() .. "\" === ")
			dev:depends("netconfig", "1")
			dev.rmempty = false
			function dev.value(self, section)
				return uci:get("freifunk", "wizard", "device_" .. device)
			end
			function dev.write(self, sec, value)
				if value then
					uci:set("freifunk", "wizard", "device_" .. device, value)
					uci:save("freifunk")
				end
			end
		local chan = f:field(ListValue, "chan_" .. device, "Freifunk Kanal einrichten")
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
			function chan.write(self, sec, value)
				if value then
					uci:set("freifunk", "wizard", "chan_" .. device, value)
					uci:save("freifunk")
				end
			end
		local meship = f:field(Value, "meship_" .. device, "Mesh IP Adresse einrichten", "Netzweit eindeutige Identifikation z.B. 104.1.1.1")
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
		local client = f:field(Flag, "client_" .. device, "DHCP anbieten")
			client:depends("device_" .. device, "1")
			client.rmempty = false
			function client.value(self, section)
				return uci:get("freifunk", "wizard", "client_" .. device)
			end
			function client.write(self, sec, value)
				uci:set("freifunk", "wizard", "client_" .. device, value)
				uci:save("freifunk")
			end
		local dhcpmesh = f:field(Value, "dhcpmesh_" .. device, "Mesh DHCP anbieten", "Netzweit eindeutiges DHCP Netz z.B. 104.1.2.1/28")
			dhcpmesh:depends("client_" .. device, "1")
			dhcpmesh.rmempty = true
			function dhcpmesh.cfgvalue(self, section)
				return uci:get("freifunk", "wizard", "dhcpmesh_" .. device)
			end
			function dhcpmesh.write(self, sec, value)
				uci:set("freifunk", "wizard", "dhcpmesh_" .. device, value)
				uci:save("freifunk")
			end
	end)

uci:foreach("network", "interface",
	function(section)
		local device = section[".name"]
		if device ~= "loopback" and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			dev = f:field(Flag, "device_" .. device , " === Drahtgebundenes Netzwerk \"" .. device:upper() .. "\" === ")
				dev:depends("netconfig", "1")
				dev.rmempty = false
				function dev.value(self, section)
					return uci:get("freifunk", "wizard", "device_" .. device)
				end
				function dev.write(self, sec, value)
					uci:set("freifunk", "wizard", "device_" .. device, value)
					uci:save("freifunk")
				end
			meship = f:field(Value, "meship_" .. device, "Mesh IP Adresse einrichten", "Netzweit eindeutige Identifikation")
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
			client = f:field(Flag, "client_" .. device, "DHCP anbieten")
				client:depends("device_" .. device, "1")
				client.rmempty = false
				function client.value(self, section)
					return uci:get("freifunk", "wizard", "client_" .. device)
				end
				function client.write(self, sec, value)
					uci:set("freifunk", "wizard", "client_" .. device, value)
					uci:save("freifunk")
				end
			dhcpmesh = f:field(Value, "dhcpmesh_" .. device, "Mesh DHCP anbieten ", "Netzweit eindeutiges DHCP Netz")
				dhcpmesh:depends("client_" .. device, "1")
				dhcpmesh.rmempty = true
				function dhcpmesh.cfgvalue(self, section)
					return uci:get("freifunk", "wizard", "dhcpmesh_" .. device)
				end
				function dhcpmesh.write(self, sec, value)
					uci:set("freifunk", "wizard", "dhcpmesh_" .. device, value)
					uci:save("freifunk")
				end
		end
	end)

olsr = f:field(Flag, "olsr", " === OLSR einrichten === ")
olsr.rmempty = true

lat = f:field(Value, "lat", "Latitude")
lat:depends("olsr", "1")
function lat.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "latitude")
end
function lat.write(self, section, value)
	uci:set("freifunk", "wizard", "latitude", value)
	uci:save("freifunk")
end

lon = f:field(Value, "lon", "Longitude")
lon:depends("olsr", "1")
function lon.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "longitude")
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
self.centerlat = "0"
self.centerlon = "0"
self.zoom = "0"
self.width = "100%" --popups will ignore the %-symbol, "100%" is interpreted as "100"
self.height = "600"
self.popup = false
self.displaytext="OpenStreetMap" --text on button, that loads and displays the OSMap
self.hidetext="X" -- text on button, that hides OSMap
end

osm = f:field(OpenStreetMapLonLat, "latlon", "Geokoordinaten mit OpenStreetMap ermitteln:")
osm:depends("olsr", "1")
osm.latfield = "lat"
osm.lonfield = "lon"
osm.centerlat = uci:get("freifunk", "wizard", "latitude") or "52"
osm.centerlon = uci:get("freifunk", "wizard", "longitude") or "10"
osm.width = "100%"
osm.height = "600"
osm.popup = false
osm.zoom = "12"
osm.displaytext="OpenStreetMap anzeigen"
osm.hidetext="OpenStreetMap verbergen"

share = f:field(Flag, "sharenet", "Eigenen Internetzugang freigeben")
share.rmempty = false

wansec = f:field(Flag, "wansec", "WAN-Zugriff auf Gateway beschränken")
wansec.rmempty = false
wansec:depends("sharenet", "1")
function wansec.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "wan_security")
end
function wansec.write(self, section, value)
	uci:set("freifunk", "wizard", "wan_security", value)
	uci:save("freifunk")
end
hb = f:field(Flag, "hb", "Heartbeat aktivieren","Dem Gerät erlauben anonyme Statistiken zu übertragen.")
hb.rmempty = false
function hb.cfgvalue(self, section)
	return uci:get("freifunk", "wizard", "hb")
end


-------------------- Control --------------------
function f.handle(self, state, data)
	if state == FORM_VALID then
		local debug = uci:get("freifunk", "wizard", "debug")
		if debug == 1 then
			luci.http.redirect(luci.dispatcher.build_url("admin", "system", "system"))
		else
			uci:commit("freifunk")
			uci:commit("wireless")
			uci:commit("network")
			uci:commit("dhcp")
			uci:commit("luci_splash")
			uci:commit("firewall")
			uci:commit("system")
			uci:commit("uhttpd")
			uci:commit("olsrd")
			uci:commit("qos")
			uci:commit("manager")
			luci.http.redirect(luci.dispatcher.build_url("admin", "system", "reboot") .. "?reboot=1")
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
	if value == "0" then
		return
	end
	-- Collect IP-Address
	local community = net:formvalue(section)

	-- Invalidate fields
	if not community then
		net.tag_missing[section] = true
		return
	end

	local external
	external = uci:get("freifunk", community, "external") or ""

	local netname = "wireless"
	local network
	network = ip.IPv4(uci:get("freifunk", community, "mesh_network") or "104.0.0.0/8")

	-- Tune community settings
	if community and uci:get("freifunk", community) then
		uci:tset("freifunk", "community", uci:get_all("freifunk", community))
	end

	-- Cleanup
	uci:delete_all("firewall","zone", {name="freifunk"})
	uci:save("firewall")
	-- Create firewall zone and add default rules (first time)
	--                    firewall_create_zone("name"    , "input" , "output", "forward ", Masqurade)
	local newzone = tools.firewall_create_zone("freifunk", "ACCEPT", "ACCEPT", "REJECT"  , true)
	if newzone then
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
	uci:delete("manager", "heartbeat", "interface")
	uci:save("manager")

	-- Create wireless ip and firewall config
	uci:foreach("wireless", "wifi-device",
	function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
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
		-- tools.network_remove_interface(device)
		uci:delete("network", device .. "dhcp")
		uci:delete("network", device)
		tools.firewall_zone_remove_interface("freifunk", device)
		-- tools.network_remove_interface(nif)
		uci:delete("network", nif .. "dhcp")
		uci:delete("network", nif)
		tools.firewall_zone_remove_interface("freifunk", nif)
		-- Delete old dhcp
		uci:delete("dhcp", "dhcp", device)
		uci:delete("dhcp", "dhcp", device .. "dhcp")
		uci:delete("dhcp", "dhcp", nif)
		uci:delete("dhcp", "dhcp", nif .. "dhcp")

		-- Delete old splash
		uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
		uci:delete_all("luci_splash", "iface", {network=nif.."dhcp", zone="freifunk"})
		-- New Config
		-- Tune wifi device
		local ssiduci = uci:get("freifunk", community, "ssid")
		local ssiddot = string.find(ssiduci,'%..*')
		local ssidshort
		if ssiddot then
			ssidshort = string.sub(ssiduci,ssiddot)
		else
			ssidshort = ssiduci
		end

		local devconfig = uci:get_all("freifunk", "wifi_device")
		util.update(devconfig, uci:get_all(external, "wifi_device") or {})
		local ssid = uci:get("freifunk", community, "ssid")
		local channel = luci.http.formvalue("cbid.ffwizward.1.chan_" .. device)
		local hwmode = "11bg"
		if channel and channel ~= "default" then
			if devconfig.channel ~= channel then
				devconfig.channel = channel
				bssid = "02:CA:FF:EE:BA:BE"
				local mrate = 5500
				local chan = tonumber(channel)
				if chan >= 0 and chan < 10 then
					bssid = channel .. "2:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan == 10 then
					bssid = "02:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 11 and chan <= 14 then
					bssid = string.format("%X",channel) .. "2:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 36 and chan <= 64 then
					hwmode = "11a"
					mrate = ""
					outdoor = 0
					bssid = "00:" .. channel .."CA:FF:EE:EE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 100 and chan <= 140 then
					hwmode = "11a"
					mrate = ""
					outdoor = 1
					bssid = "01:" .. string.sub(channel, 2) .. ":CA:FF:EE:EE"
					ssid = "ch" .. channel .. ssidshort
				end
				devconfig.hwmode = hwmode
				devconfig.outdoor = outdoor
				devconfig.mrate = mrate
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
		if bssid then
			-- See Table https://kifuse02.pberg.freifunk.net/moin/channel-bssid-essid 
			ifconfig.bssid = bssid
		end
		uci:section("wireless", "wifi-iface", nil, ifconfig)
		uci:save("wireless")
		local netconfig = uci:get_all("freifunk", "interface")
		util.update(netconfig, uci:get_all(external, "interface") or {})
		netconfig.proto = "static"
		netconfig.ipaddr = node_ip:string()
		uci:section("network", "interface", nif, netconfig)
		uci:save("network")
		local new_hostname = node_ip:string():gsub("%.", "-")
		uci:set("freifunk", "wizard", "hostname", new_hostname)
		uci:save("freifunk")
		tools.firewall_zone_add_interface("freifunk", nif)
		uci:save("firewall")
		-- Collect MESH DHCP IP NET
		local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
		if client then
			local dhcpmeshnet = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
			uci:set_list("manager", "heartbeat", "interface", nif)
			uci:save("manager")
			if dhcpmeshnet then
				dhcp_ip = dhcpmeshnet:minhost():string()
				dhcp_mask = dhcpmeshnet:mask():string()
			else
				local subnet_prefix = tonumber(uci:get("freifunk", community, "splash_prefix")) or 27
				local pool_network = uci:get("freifunk", community, "splash_network") or "10.104.0.0/16"
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
				end
			end
			if dhcp_ip and dhcp_mask then
				-- Create alias
				local aliasbase = uci:get_all("freifunk", "alias")
				util.update(aliasbase, uci:get_all(external, "alias") or {})
				aliasbase.interface = nif
				aliasbase.ipaddr = dhcp_ip
				aliasbase.netmask = dhcp_mask
				aliasbase.proto = "static"
				uci:section("network", "alias", nif .. "dhcp", aliasbase)
				-- Create dhcp
				local dhcpbase = uci:get_all("freifunk", "dhcp")
				util.update(dhcpbase, uci:get_all(external, "dhcp") or {})
				dhcpbase.interface = nif .. "dhcp"
				dhcpbase.force = 1
				uci:section("dhcp", "dhcp", nif .. "dhcp", dhcpbase)
				uci:set_list("dhcp", nif .. "dhcp", "dhcp_option", "119,olsr")
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
				sys.exec("/etc/init.d/luci_splash enable")
			end
		else
			-- Delete old splash
			uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
--[[			sys.exec("/etc/init.d/luci_splash stop")
			sys.exec("/etc/init.d/luci_splash disable")]]
		end
		uci:save("wireless")
		uci:save("network")
		uci:save("firewall")
		uci:save("dhcp")
	end)
	-- Create wired ip and firewall config
	uci:foreach("network", "interface",
		function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		if device ~= "loopback" and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			local node_ip
			node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
			if not node_ip or not network or not network:contains(node_ip) then
				meship.tag_missing[section] = true
				node_ip = nil
				return
			end
			-- Cleanup
			tools.firewall_zone_remove_interface(device, device)
			uci:delete_all("firewall","zone", {name=device})
			uci:delete_all("firewall","forwarding", {src=device})
			uci:delete_all("firewall","forwarding", {dest=device})
			uci:delete("network", device .. "dhcp")
			-- Delete old dhcp
			uci:delete("dhcp", "dhcp", device)
			uci:delete("dhcp", "dhcp", device .. "dhcp")
			-- Delete old splash
			uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
			-- New Config
			local netconfig = uci:get_all("freifunk", "interface")
			util.update(netconfig, uci:get_all(external, "interface") or {})
			netconfig.proto = "static"
			netconfig.ipaddr = node_ip:string()
			uci:section("network", "interface", device, netconfig)
			uci:save("network")
			local new_hostname = node_ip:string():gsub("%.", "-")
			uci:set("freifunk", "wizard", "hostname", new_hostname)
			uci:save("freifunk")
			tools.firewall_zone_add_interface("freifunk", device)
			uci:save("firewall")
			-- Collect MESH DHCP IP NET
			local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
			if client then
				local dhcpmeshnet = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
				uci:set_list("manager", "hertbeat", "interface", device)
				uci:save("manager")
				if dhcpmeshnet then
					dhcp_ip = dhcpmeshnet:minhost():string()
					dhcp_mask = dhcpmeshnet:mask():string()
				else
					local subnet_prefix = tonumber(uci:get("freifunk", community, "splash_prefix")) or 27
					local pool_network = uci:get("freifunk", community, "splash_network") or "10.104.0.0/16"
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
					end
				end
				if dhcp_ip and dhcp_mask then
					-- Create alias
					local aliasbase = uci:get_all("freifunk", "alias")
					util.update(aliasbase, uci:get_all(external, "alias") or {})
					aliasbase.interface = device
					aliasbase.ipaddr = dhcp_ip
					aliasbase.netmask = dhcp_mask
					aliasbase.proto = "static"
					uci:section("network", "alias", device .. "dhcp", aliasbase)
					-- Create dhcp
					local dhcpbase = uci:get_all("freifunk", "dhcp")
					util.update(dhcpbase, uci:get_all(external, "dhcp") or {})
					dhcpbase.interface = device .. "dhcp"
					dhcpbase.force = 1
					uci:section("dhcp", "dhcp", device .. "dhcp", dhcpbase)
					uci:set_list("dhcp", device .. "dhcp", "dhcp_option", "119,olsr")
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
					sys.exec("/etc/init.d/luci_splash enable")
				end
			end
			uci:save("wireless")
			uci:save("network")
			uci:save("firewall")
			uci:save("dhcp")
		end
	end)

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
	uci:save("wireless")
	uci:save("network")
	uci:save("firewall")
	uci:save("dhcp")

	local new_hostname = uci:get("freifunk", "wizard", "hostname")
	local old_hostname = sys.hostname()

	local dhcphb = hb:formvalue(section)
	if dhcphb then
		uci:set("manager", "heartbeat", "enabled", "1")
		-- Make sure that OLSR is enabled
		sys.exec("/etc/init.d/machash enable")
	else
		uci:set("manager", "heartbeat", "enabled", "0")
		-- Make sure that OLSR is enabled
		sys.exec("/etc/init.d/machash disable")
	end
	uci:save("manager")

	uci:foreach("system", "system",
		function(s)
			-- Make crond silent
			uci:set("system", s['.name'], "cronloglevel", "10")

			-- Set hostname
			if new_hostname then
				if old_hostname == "OpenWrt" or old_hostname:match("^%d+-%d+-%d+-%d+$") then
					uci:set("system", s['.name'], "hostname", new_hostname)
					sys.hostname(new_hostname)
				end
			end
		end)

	uci:save("system")
	uci:set("uhttpd","main","listen_http","0.0.0.0:80 0.0.0.0:8082")
	uci:save("uhttpd")
end


function olsr.write(self, section, value)
	if value == "0" then
		return
	end


	local netname = "wireless"
	local community = net:formvalue(section)
	local external  = community and uci:get("freifunk", community, "external") or ""
	local network = ip.IPv4(uci:get("freifunk", community, "mesh_network") or "104.0.0.0/8")

	local latval = tonumber(lat:formvalue(section))
	local lonval = tonumber(lon:formvalue(section))

	-- Delete olsrd
	uci:delete_all("olsrd", "olsrd")
	local olsrbase
	olsrbase = uci:get_all("freifunk", "olsrd") or {}
	util.update(olsrbase, uci:get_all(external, "olsrd") or {})
	uci:section("olsrd", "olsrd", nil, olsrbase)

	-- Delete old p2pd settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_mdns.so.1.0.0"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_p2pd.so.0.1.0"})
	-- Write new nameservice settings
	uci:section("olsrd", "LoadPlugin", nil, {
		library     = "olsrd_p2pd.so.0.1.0",
		P2pdTtl     = 10,
		UdpDestPort = "224.0.0.251 5353",
		ignore      = 1,
	})
	-- Delete/Disable gateway plugins
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
	uci:section("olsrd", "LoadPlugin", nil, {
		library     = "olsrd_dyn_gw_plain.so.0.4",
		ignore      = 1,
	})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})
	-- Delete http plugin
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_httpinfo.so.0.1"})

	-- Delete old interface
	uci:delete_all("olsrd", "Interface")
	uci:delete_all("olsrd", "Hna4")
	-- Create wireless olsr config
	uci:foreach("wireless", "wifi-device",
	function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		local node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
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

		-- Write new interface
		local olsrifbase = uci:get_all("freifunk", "olsr_interface")
		util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
		olsrifbase.interface = nif
		olsrifbase.ignore    = "0"
		uci:section("olsrd", "Interface", nil, olsrifbase)
		-- Collect MESH DHCP IP NET
		local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
		if client then
			local dhcpmesh = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
			if dhcpmesh then
				local mask = dhcpmesh:mask():string()
				local network = dhcpmesh:network():string()
				uci:section("olsrd", "Hna4", nil, {
					netmask  = mask,
					netaddr  = network
				})
				uci:foreach("olsrd", "LoadPlugin",
					function(s)		
						if s.library == "olsrd_p2pd.so.0.1.0" then
							uci:set("olsrd", s['.name'], "ignore", "0")
							uci:set("olsrd", s['.name'], "NonOlsrIf", nif)
						end
					end)
			end
		end
	end)
	-- Create wired olsrd config
	uci:foreach("network", "interface",
		function(sec)
		local device = sec[".name"]
		if device ~= "loopback" and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			local node_ip
			if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
				return
			end
			node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
			if not node_ip or not network or not network:contains(node_ip) then
				meship.tag_missing[section] = true
				node_ip = nil
				return
			end
			-- Write new interface
			local olsrifbase = uci:get_all("freifunk", "olsr_interface")
			util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
			olsrifbase.interface = device
			olsrifbase.ignore    = "0"
			uci:section("olsrd", "Interface", nil, olsrifbase)
			-- Collect MESH DHCP IP NET
			local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
			if client then
				local dhcpmesh = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
				if dhcpmesh then
					local mask = dhcpmesh:mask():string()
					local network = dhcpmesh:network():string()
					uci:section("olsrd", "Hna4", nil, {
						netmask  = mask,
						netaddr  = network
					})
					uci:foreach("olsrd", "LoadPlugin",
						function(s)		
							if s.library == "olsrd_mdns.so.1.0.0" then
								uci:set("olsrd", s['.name'], "ignore", "0")
								uci:set_list("olsrd", s['.name'], "NonOlsrIf", device)
							end
						end)
				end
			end
		end
	end)


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
		suffix      = ".olsr",
		hosts_file  = "/var/etc/hosts.olsr",
		latlon_file = "/var/run/latlon.js",
		lat         = latval and string.format("%.15f", latval) or "",
		lon         = lonval and string.format("%.15f", lonval) or ""
	})

	-- Save latlon to system too
	if latval and lonval then
		uci:foreach("system", "system", function(s)
			uci:set("system", s[".name"], "latlon",
				string.format("%.15f %.15f", latval, lonval))
		end)
	else
		uci:foreach("system", "system", function(s)
			uci:delete("system", s[".name"], "latlon")
		end)
	end

	-- Import hosts and set domain
	uci:foreach("dhcp", "dnsmasq", function(s)
		uci:set_list("dhcp", s[".name"], "addnhosts", "/var/etc/hosts.olsr")
		uci:set("dhcp", s[".name"], "local", "/olsr/")
		uci:set("dhcp", s[".name"], "domain", "olsr")
	end)

	-- Make sure that OLSR is enabled
	sys.exec("/etc/init.d/olsrd enable")

	uci:save("olsrd")
	uci:save("dhcp")
end


function share.write(self, section, value)
	sys.init.disable("freifunk-p2pblock")
	sys.init.disable("qos")
	uci:delete_all("firewall", "forwarding", {src="freifunk", dest="wan"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
	uci:foreach("firewall", "zone",
		function(s)		
			if s.name == "wan" then
				uci:delete("firewall", s['.name'], "local_restrict")
				return false
			end
		end)

	if value == "1" then
		uci:section("firewall", "forwarding", nil, {src="freifunk", dest="wan"})
		uci:section("olsrd", "LoadPlugin", nil, {library="olsrd_dyn_gw_plain.so.0.4"})

		if wansec:formvalue(section) == "1" then
			uci:foreach("firewall", "zone",
				function(s)		
					if s.name == "wan" then
						uci:set("firewall", s['.name'], "local_restrict", "1")
						return false
					end
				end)
		end
	end
	sys.exec('echo "0 6 * * * 	ifup wan" >> /etc/crontabs/root')

	uci:save("firewall")
	uci:save("olsrd")
	uci:save("system")
end

return f
