--[[
LuCI - Lua Configuration Interface

Copyright 2013 Patrick Grimm <patrick@lunatiki.de>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id$

]]--

local bus = require "ubus"
local string = require "string"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor_state()
local util = require "luci.util"
local webadmin = require "luci.tools.webadmin"
local status = require "luci.tools.status"
local json = require "luci.json"
local netm = require "luci.model.network"
local sysinfo = luci.util.ubus("system", "info") or { }
local boardinfo = luci.util.ubus("system", "board") or { }
local table = require "table"
local nixio = require "nixio"
--local neightbl = require "neightbl"
local ip = require "luci.ip"


local ipairs, os, pairs, next, type, tostring, tonumber, error, print =
	ipairs, os, pairs, next, type, tostring, tonumber, error, print

local dofile, _G = dofile, _G

--- LuCI OWM-Library
-- @cstyle	instance
module "luci.owm"


-- backported from LuCI 0.11 and adapted form berlin-stats
--- Returns the system type (in a compatible way to LuCI 0.11)
-- @return	String indicating this as an deprecated value
--        	(instead of the Chipset-type)
-- @return	String containing hardware model information
--        	(trimmed to router-model only)
function sysinfo_for_kathleen020()
	local cpuinfo = nixio.fs.readfile("/proc/cpuinfo")

	local system = 'system is deprecated'

	local model = 
		boardinfo['model'] or
		cpuinfo:match("machine\t+: ([^\n]+)") or
		cpuinfo:match("Hardware\t+: ([^\n]+)") or
		nixio.uname().machine or
		system

        return system, model
end

-- inspired by luci.version
--- Returns the system version info build from /etc/openwrt_release
--- switch from luci.version which always includes
--- the revision in the "distversion" field and gives empty "distname"
-- @ return	the releasename 
--         	(DISTRIB_ID + DISTRIB_CODENAME + DISTRIB_RELEASE)
-- @ return	the releaserevision
--         	(DISTRIB_REVISION)
function get_version()
	local distname = ""
	local distrev = ""
	local version = {}

	dofile("/etc/openwrt_release")
	if _G.DISTRIB_ID then
		distname = _G.DISTRIB_ID .. " "
	end
	if _G.DISTRIB_CODENAME then
		distname = distname .. _G.DISTRIB_CODENAME .. " "
	end
	if _G.DISTRIB_RELEASE then
		distname = distname .. _G.DISTRIB_RELEASE
	end
	if _G.DISTRIB_REVISION then
		distrev = _G.DISTRIB_REVISION
	end
	version['distname'] = distname
	version['distrevision'] = distrev
	return version
end

function fetch_olsrd_config()
	local jsonreq4 = ""
	local jsonreq6 = ""
	local data = {}
	local IpVersion = uci:get_first("olsrd", "olsrd","IpVersion")
	if IpVersion == "4" or IpVersion == "6and4" then
		local jsonreq4 = util.exec("echo /config | nc 127.0.0.1 9090 2>/dev/null") or {}
		local jsondata4 = json.decode(jsonreq4) or {}
		--print("fetch_olsrd_config v4 "..(jsondata4['config'] and "1" or "err"))
		if jsondata4['config'] then
			data['ipv4Config'] = jsondata4['config']
		end
	end
	if IpVersion == "6" or IpVersion == "6and4" then
		local jsonreq6 = util.exec("echo /config | nc ::1 9090 2>/dev/null") or {}
		local jsondata6 = json.decode(jsonreq6) or {}
		--print("fetch_olsrd_config v6 "..(jsondata6['config'] and "1" or "err"))
		if jsondata6['config'] then
			data['ipv6Config'] = jsondata6['config']
		end
	end
	return data
end

function fetch_olsrd_links()
	local jsonreq4 = ""
	local jsonreq6 = ""
	local data = {}
	local IpVersion = uci:get_first("olsrd", "olsrd","IpVersion")
	if IpVersion == "4" or IpVersion == "6and4" then
		local jsonreq4 = util.exec("echo /links | nc 127.0.0.1 9090 2>/dev/null") or {}
		local jsondata4 = json.decode(jsonreq4) or {}
		--print("fetch_olsrd_links v4 "..(jsondata4['links'] and #jsondata4['links'] or "err"))
		local links = {}
		if jsondata4['links'] then
			links = jsondata4['links']
		end
		for i,v in ipairs(links) do
			links[i]['sourceAddr'] = v['localIP'] --owm sourceAddr
			links[i]['destAddr'] = v['remoteIP'] --owm destAddr
			hostname = nixio.getnameinfo(v['remoteIP'], "inet")
			if hostname then
				links[i]['destNodeId'] = string.gsub(hostname, "mid..", "") --owm destNodeId
			end 
		end
		data = links
	end
	if IpVersion == "6" or IpVersion == "6and4" then
		local jsonreq6 = util.exec("echo /links | nc ::1 9090 2>/dev/null") or {}
		local jsondata6 = json.decode(jsonreq6) or {}
		--print("fetch_olsrd_links v6 "..(jsondata6['links'] and #jsondata6['links'] or "err"))
		local links = {}
		if jsondata6['links'] then
			links = jsondata6['links']
		end
		for i,v in ipairs(links) do
			links[i]['sourceAddr'] = v['localIP']
			links[i]['destAddr'] = v['remoteIP']
			hostname = nixio.getnameinfo(v['remoteIP'], "inet6")
			if hostname then
				links[i]['destNodeId'] = string.gsub(hostname, "mid..", "") --owm destNodeId
			end
			data[#data+1] = links[i]
		end
	end
	return data
end

function fetch_olsrd_neighbors(interfaces)
	local jsonreq4 = ""
	local jsonreq6 = ""
	local data = {}
	local IpVersion = uci:get_first("olsrd", "olsrd","IpVersion")
	if IpVersion == "4" or IpVersion == "6and4" then
		local jsonreq4 = util.exec("echo /links | nc 127.0.0.1 9090 2>/dev/null") or {}
		local jsondata4 = json.decode(jsonreq4) or {}
		--print("fetch_olsrd_neighbors v4 "..(jsondata4['links'] and #jsondata4['links'] or "err"))
		local links = {}
		if jsondata4['links'] then
			links = jsondata4['links']
		end
		for _,v in ipairs(links) do
			local hostname = nixio.getnameinfo(v['remoteIP'], "inet")
			if hostname then
				hostname = string.gsub(hostname, "mid..", "")
				local index = #data+1
				data[index] = {}
				data[index]['id'] = hostname --owm
				data[index]['quality'] = v['linkQuality'] --owm
				data[index]['sourceAddr4'] = v['localIP'] --owm
				data[index]['destAddr4'] = v['remoteIP'] --owm
				if #interfaces ~= 0 then
					for _,iface in ipairs(interfaces) do
						if iface['ipaddr'] == v['localIP'] then
							data[index]['interface'] = iface['name'] --owm
						end
					end
				end
				data[index]['olsr_ipv4'] = v
			end
		end
	end
	if IpVersion == "6" or IpVersion == "6and4" then
		local jsonreq6 = util.exec("echo /links | nc ::1 9090 2>/dev/null") or {}
		local jsondata6 = json.decode(jsonreq6) or {}
		--print("fetch_olsrd_neighbors v6 "..(jsondata6['links'] and #jsondata6['links'] or "err"))
		local links = {}
		if jsondata6['links'] then
			links = jsondata6['links']
		end
		for _,v in ipairs(links) do
			local hostname = nixio.getnameinfo(v['remoteIP'], "inet6")
			if hostname then
				hostname = string.gsub(hostname, "mid..", "")
				local index = 0
				for i, v in ipairs(data) do
					if v.id == hostname then
						index = i
					end
				end
				if index == 0 then
					index = #data+1
					data[index] = {}
					data[index]['id'] = string.gsub(hostname, "mid..", "") --owm
					data[index]['quality'] = v['linkQuality'] --owm
					if #interfaces ~= 0 then
						for _,iface in ipairs(interfaces) do
							local name = iface['.name']
							local net = netm:get_network(name)
							local device = net and net:get_interface()
							if device and device:ip6addrs() then
								local_ip = ip.IPv6(v.localIP)
								for _, a in ipairs(device:ip6addrs()) do
									if a:host() == local_ip:host() then
										data[index]['interface'] = name
									end
								end
							end
						end
					end
				end
				data[index]['sourceAddr6'] = v['localIP'] --owm
				data[index]['destAddr6'] = v['remoteIP'] --owm
				data[index]['olsr_ipv6'] = v
			end
		end
	end
	return data
end

function fetch_olsrd()
	local data = {}
	data['links'] = fetch_olsrd_links()
	local olsrconfig = fetch_olsrd_config()
	data['ipv4Config'] = olsrconfig['ipv4Config']
	data['ipv6Config'] = olsrconfig['ipv6Config']
	
	return data
end

function showmac(mac)
	if not is_admin then
		mac = mac:gsub("(%S%S:%S%S):%S%S:%S%S:(%S%S:%S%S)", "%1:XX:XX:%2")
	end
	return mac
end

function get_position()
	local position = {}
	uci:foreach("system", "system", function(s)
		position['latitude'] = tonumber(s.latitude)
		position['longitude'] = tonumber(s.longitude)
	end)
	if (position['latitude'] and  position['longitude']) then
		return position
	else
		return nil
	end
end

function get()
	local root = {}
	local ntm = netm.init()
	local devices  = ntm:get_wifidevs()
	local assoclist = {}
	local _ubus = bus.connect()
	local _ubusclicache = { }
	local position = get_position()
	local version = get_version()
--	local _, object
--	for _, object in ipairs(_ubus:objects()) do
--		local _ubusclicache = object:match("^clicache%.(.+)")
--		print(_ubusclicache)
--	end
	for _, dev in ipairs(devices) do
		for _, net in ipairs(dev:get_wifinets()) do
			assoclist[#assoclist+1] = {} 
			assoclist[#assoclist]['ifname'] = net.iwdata.ifname
			assoclist[#assoclist]['network'] = net.iwdata.network
			assoclist[#assoclist]['device'] = net.iwdata.device
			assoclist[#assoclist]['list'] = net.iwinfo.assoclist
		end
	end
	root.type = 'node' --owm
	root.updateInterval = 3600 --owm one hour

	root.system = {
		uptime = {sys.uptime()},
		loadavg = {sysinfo.load[1] / 65536.0},
		sysinfo = {sysinfo_for_kathleen020()},
	}
	root.hostname = sys.hostname() --owm


	root.hardware = boardinfo['system'] --owm
	

	root.firmware = {
	--	luciname=version.luciname,
	--	luciversion=version.luciversion,
	--	distname=version.distname,
		name=version.distname, --owm
	--	distversion=version.distversion,
		revision=version.distrevision --owm
	}

	root.freifunk = {}
	uci:foreach("freifunk", "public", function(s)
		local pname = s[".name"]
		s['.name'] = nil
		s['.anonymous'] = nil
		s['.type'] = nil
		s['.index'] = nil
		if s['mail'] then
			s['mail'] = string.gsub(s['mail'], "@", "./-\\.T.")
		end
		root.freifunk[pname] = s
	end)

	root.latitude = position["latitude"] --owm
	root.longitude = position["longitude"] --owm

	local devices = {}
	uci:foreach("wireless", "wifi-device",function(s)
		devices[#devices+1] = s
		devices[#devices]['name'] = s['.name']
		devices[#devices]['.name'] = nil
		devices[#devices]['.anonymous'] = nil
		devices[#devices]['.type'] = nil
		devices[#devices]['.index'] = nil
		if s.macaddr then
			devices[#devices]['macaddr'] = showmac(s.macaddr)
		end
	end)
	local antennas = {}
	uci:foreach("antennas", "wifi-device",function(s)
		antennas[#antennas+1] = s
		antennas[#antennas]['name'] = s['.name']
		antennas[#antennas]['.name'] = nil
		antennas[#antennas]['.anonymous'] = nil
		antennas[#antennas]['.type'] = nil
		antennas[#antennas]['.index'] = nil
	end)

	local interfaces = {}
	uci:foreach("wireless", "wifi-iface",function(s)
		interfaces[#interfaces+1] = s
		interfaces[#interfaces]['.name'] = nil
		interfaces[#interfaces]['.anonymous'] = nil
		interfaces[#interfaces]['.type'] = nil
		interfaces[#interfaces]['.index'] = nil
		interfaces[#interfaces]['key'] = nil
		interfaces[#interfaces]['key1'] = nil
		interfaces[#interfaces]['key2'] = nil
		interfaces[#interfaces]['key3'] = nil
		interfaces[#interfaces]['key4'] = nil
		interfaces[#interfaces]['auth_secret'] = nil
		interfaces[#interfaces]['acct_secret'] = nil
		interfaces[#interfaces]['nasid'] = nil
		interfaces[#interfaces]['identity'] = nil
		interfaces[#interfaces]['password'] = nil
		local iwinfo = sys.wifi.getiwinfo(s.ifname)
		if iwinfo then
			local _, f
			for _, f in ipairs({
			"channel", "txpower", "bitrate", "signal", "noise",
			"quality", "quality_max", "mode", "ssid", "bssid", "encryption", "ifname"
			}) do
				interfaces[#interfaces][f] = iwinfo[f]
			end
			if iwinfo['encryption'] then
				if iwinfo['encryption']['enabled'] then
					-- fingers off encrypted wifi interfaces, they are likely private
					table.remove(interfaces)
					return
				end
			end
		end
		assoclist_if = {}
		for _, v in ipairs(assoclist) do
			if v.network == interfaces[#interfaces]['network'] and v.list then
				for assocmac, assot in pairs(v.list) do
					assoclist_if[#assoclist_if+1] = assot
					assoclist_if[#assoclist_if].mac = showmac(assocmac)
				end
			end
		end
		interfaces[#interfaces]['assoclist'] = assoclist_if
		for ii,vv in ipairs(devices) do
			if s['device'] == vv.name then
				interfaces[#interfaces]['wirelessdevice'] = vv
			end
		end
		for ii,vv in ipairs(antennas) do
			if s['device'] == vv.name then
				interfaces[#interfaces]['wirelessdevice']['antenna'] = vv --owm
			end
		end
	end)

	root.interfaces = {} --owm
	uci:foreach("network", "interface",function(vif)
		if 'lo' == vif.ifname then
			return
		end
		local name = vif['.name']
		if ('wan' == name) or ('wan6' == name) then
			-- fingers off wan as this will be the private internet uplink
			return
		end
		local net = netm:get_network(name)
		local device = net and net:get_interface()
		root.interfaces[#root.interfaces+1] =  vif
		root.interfaces[#root.interfaces].name = name --owm
		root.interfaces[#root.interfaces].ifname = vif.ifname --owm
		root.interfaces[#root.interfaces].ipv4Addresses = {vif.ipaddr} --owm
		if device and device:ip6addrs() then
			local ipv6Addresses = {}
			for _, a in ipairs(device:ip6addrs()) do
				table.insert(ipv6Addresses, a:string())
			end
		end
		root.interfaces[#root.interfaces].ipv6Addresses = ipv6Addresses --owm
		root.interfaces[#root.interfaces].physicalType = 'ethernet' --owm
		root.interfaces[#root.interfaces]['.name'] = nil
		root.interfaces[#root.interfaces]['.anonymous'] = nil
		root.interfaces[#root.interfaces]['.type'] = nil
		root.interfaces[#root.interfaces]['.index'] = nil
		root.interfaces[#root.interfaces]['username'] = nil
		root.interfaces[#root.interfaces]['password'] = nil
		root.interfaces[#root.interfaces]['password'] = nil
		root.interfaces[#root.interfaces]['clientid'] = nil
		root.interfaces[#root.interfaces]['reqopts'] = nil
		root.interfaces[#root.interfaces]['pincode'] = nil
		root.interfaces[#root.interfaces]['tunnelid'] = nil
		root.interfaces[#root.interfaces]['tunnel_id'] = nil
		root.interfaces[#root.interfaces]['peer_tunnel_id'] = nil
		root.interfaces[#root.interfaces]['session_id'] = nil
		root.interfaces[#root.interfaces]['peer_session_id'] = nil
		if vif.macaddr then
			root.interfaces[#root.interfaces]['macaddr'] = showmac(vif.macaddr)
		end
		
		wireless_add = {}
		for i,v in ipairs(interfaces) do
			if v['network'] == name then
				root.interfaces[#root.interfaces].physicalType = 'wifi' --owm
				root.interfaces[#root.interfaces].mode = v.mode
				root.interfaces[#root.interfaces].encryption = v.encryption
				root.interfaces[#root.interfaces].access = 'free'
				root.interfaces[#root.interfaces].accessNote = "everyone is welcome!"
				root.interfaces[#root.interfaces].channel = v.wirelessdevice.channel
				root.interfaces[#root.interfaces].txpower = v.wirelessdevice.txpower
				root.interfaces[#root.interfaces].bssid = v.bssid
				root.interfaces[#root.interfaces].ssid = v.ssid
				root.interfaces[#root.interfaces].antenna = v.wirelessdevice.antenna
				wireless_add[#wireless_add+1] = v --owm
			end
		end
		root.interfaces[#root.interfaces].wifi = wireless_add
	end)

--[[
	local dr4 = sys.net.defaultroute()
	local dr6 = sys.net.defaultroute6()
	
	if dr6 then
		def6 = { 
		gateway = dr6.nexthop:string(),
		dest = dr6.dest:string(),
		dev = dr6.device,
		metr = dr6.metric }
	end   

	if dr4 then
		def4 = { 
		gateway = dr4.gateway:string(),
		dest = dr4.dest:string(),
		dev = dr4.device,
		metr = dr4.metric }
	else
		local dr = sys.exec("ip r s t olsr-default")
		if dr then
			local dest, gateway, dev, metr = dr:match("^(%w+) via (%d+.%d+.%d+.%d+) dev (%w+) +metric (%d+)")
			def4 = {
				dest = dest,
				gateway = gateway,
				dev = dev,
				metr = metr
			}
		end
	end

	root.ipv4defaultGateway = def4
	root.ipv6defaultGateway = def6
--]]

	local neighbors = fetch_olsrd_neighbors(root.interfaces)
	local arptable = sys.net.arptable() or {}
	if #root.interfaces ~= 0 then
		for idx,iface in ipairs(root.interfaces) do
			local t = {}
			if iface['ifname'] and neightbl then
				t = neightbl.get(iface['ifname']) or {}
				local neightbl_get
				for ip,mac in pairs(t) do
					if not mac then
						os.execute("ping6 -q -c1 -w1 -I"..iface['ifname'].." "..ip.." 2&>1 >/dev/null")
						neightbl_get = true
					end
				end
				if neightbl_get then
					t = neightbl.get(iface['ifname']) or {}
				end
			end
			local neigh_mac = {}
			for ip,mac in pairs(t) do
				if mac and not string.find(mac, "33:33:") then
					mac = showmac(mac)
					if not neigh_mac[mac] then
						neigh_mac[mac] = {}
						neigh_mac[mac]['ip6'] = {}
					elseif not neigh_mac[mac]['ip6'] then
						neigh_mac[mac]['ip6'] = {}
					end
					neigh_mac[mac]['ip6'][#neigh_mac[mac]['ip6']+1] = ip
					for i, neigh in ipairs(neighbors) do
						if neigh['destAddr6'] == ip then
							neighbors[i]['mac'] = mac
							neighbors[i]['ifname'] = iface['ifname']
						end
					end
				end
			end
			for _, arpt in ipairs(arptable) do
				local mac = showmac(arpt['HW address']:lower())
				local ip = arpt['IP address']
				if iface['ifname'] == arpt['Device'] then
					if not neigh_mac[mac] then
						neigh_mac[mac] = {}
						neigh_mac[mac]['ip4'] = {}
					elseif not neigh_mac[mac]['ip4'] then
						neigh_mac[mac]['ip4'] = {}
					end
					neigh_mac[mac]['ip4'][#neigh_mac[mac]['ip4']+1] = ip
					for i, neigh in ipairs(neighbors) do
						if neigh['destAddr4'] == ip then
							neighbors[i]['mac'] = mac
							neighbors[i]['ifname'] = iface['ifname']
						end
					end
				end
			end
			for _, v in ipairs(assoclist) do
				if v.ifname == iface['ifname'] and v.list then
					for assocmac, assot in pairs(v.list) do
						local mac = showmac(assocmac:lower())
						if not neigh_mac[mac] then
							neigh_mac[mac] = {}
						end
						if not neigh_mac[mac]['ip4'] then
							neigh_mac[mac]['ip4'] = {}
						end
						if not neigh_mac[mac]['ip6'] then
							neigh_mac[mac]['ip6'] = {}
						end
						neigh_mac[mac]['wifi'] = assot
						for i, neigh in ipairs(neighbors) do
							for j, ip in ipairs(neigh_mac[mac]['ip4']) do
								if neigh['destAddr4'] == ip then
									neighbors[i]['mac'] = mac
									neighbors[i]['ifname'] = iface['ifname']
									neighbors[i]['wifi'] = assot
									neighbors[i]['signal'] = assot.signal
									neighbors[i]['noise'] = assot.noise
								end
							end
							for j, ip in ipairs(neigh_mac[mac]['ip6']) do
								if neigh['destAddr6'] == ip then
									neighbors[i]['mac'] = mac
									neighbors[i]['ifname'] = iface['ifname']
									neighbors[i]['wifi'] = assot
									neighbors[i]['signal'] = assot.signal
									neighbors[i]['noise'] = assot.noise
								end
							end
						end
					end
				end
			end
			root.interfaces[idx].neighbors = neigh_mac
		end
	end

	root.links = neighbors

	root.olsr = fetch_olsrd()

	root.script = 'luci-app-owm'
	
	root.api_rev = '1.0'

	return root
end

