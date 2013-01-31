--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

module("luci.controller.owm", package.seeall)

function index()
	entry({"owm.json"}, call("jsonowm"))

	local page = node("owm")
	page.target = template("owm")
	page.title = "OpenWifiMap"
	page.order = 100
end

local function fetch_olsrd_config()
	local sys = require "luci.sys"
	local util = require "luci.util"
	local table = require "table"
	local json = require "luci.json"
	local jsonreq4 = luci.util.exec("echo /config | nc 127.0.0.1 9090")
	local jsonreq6 = luci.util.exec("echo /config | nc ::1 9090")
	local jsondata4 = {}
	local jsondata6 = {}
	local data = {}
	if #jsonreq4 ~= 0 then
		jsondata4 = json.decode(jsonreq4)
		data['ipv4Config'] = jsondata4['data'][1]['config']
	end
	if #jsonreq6 ~= 0 then
		jsondata6 = json.decode(jsonreq6)
		data['ipv6Config'] = jsondata6['data'][1]['config']
	end
	return data
end

local function fetch_olsrd_links()
	local sys = require "luci.sys"
	local util = require "luci.util"
	local table = require "table"
	local json = require "luci.json"
	local jsonreq4 = luci.util.exec("echo /links | nc 127.0.0.1 9090")
	local jsonreq6 = luci.util.exec("echo /links | nc ::1 9090")
	local jsondata4 = {}
	local jsondata6 = {}
	local data = {}
	if #jsonreq4 ~= 0 then
		jsondata4 = json.decode(jsonreq4)
		local links = jsondata4['data'][1]['links']
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
	if #jsonreq6 ~= 0 then
		jsondata6 = json.decode(jsonreq6)
		local links = jsondata6['data'][1]['links']
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

local function fetch_olsrd_neighbors(interfaces)
	local sys = require "luci.sys"
	local util = require "luci.util"
	local table = require "table"
	local json = require "luci.json"
	local jsonreq4 = luci.util.exec("echo /links | nc 127.0.0.1 9090")
	local jsonreq6 = luci.util.exec("echo /links | nc ::1 9090")
	local jsondata4 = {}
	local jsondata6 = {}
	local data = {}
	if #jsonreq4 ~= 0 then
		jsondata4 = json.decode(jsonreq4)
		local links = jsondata4['data'][1]['links']
		for _,v in ipairs(links) do
			local hostname = nixio.getnameinfo(v['remoteIP'], "inet")
			hostname = string.gsub(hostname, "mid..", "")
			if hostname then
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
	if #jsonreq6 ~= 0 then
		jsondata6 = json.decode(jsonreq6)
		local links = jsondata6['data'][1]['links']
		for _,v in ipairs(links) do
			local hostname = nixio.getnameinfo(v['remoteIP'], "inet6")
			hostname = string.gsub(hostname, "mid..", "")
			if hostname then
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
							if iface['ip6addr'] then
								if string.gsub(iface['ip6addr'], "/64", "") == v['localIP'] then
									data[index]['interface'] = iface['name'] --owm
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

	
local function fetch_olsrd()
	local sys = require "luci.sys"
	local util = require "luci.util"
	local table = require "table"
	local data = {}
	data['links'] = fetch_olsrd_links()
	local olsrconfig = fetch_olsrd_config()
	data['ipv4Config'] = olsrconfig['ipv4Config']
	data['ipv6Config'] = olsrconfig['ipv6Config']
	
	return data
end

local function showmac(mac)
    if not is_admin then
        mac = mac:gsub("(%S%S:%S%S):%S%S:%S%S:(%S%S:%S%S)", "%1:XX:XX:%2")
    end
    return mac
end

function jsonowm()
	local root = {}
	local sys = require "luci.sys"
	local uci = require "luci.model.uci"
	local util = require "luci.util"
	local http = require "luci.http"
	local ltn12 = require "luci.ltn12"
	local version = require "luci.version"
	local webadmin = require "luci.tools.webadmin"
	local status = require "luci.tools.status"
	local json = require "luci.json"
	local ntm = require "luci.model.network".init()
	local cursor = uci.cursor_state()

	root.type = 'node' --owm
	root.lastupdate = os.date("!%Y-%m-%dT%H:%M:%SZ") --owm
	root.updateInterval = 60 --owm

	root.system = {
		uptime = {sys.uptime()},
		loadavg = {sys.loadavg()},
		sysinfo = {sys.sysinfo()},
	}
	root.hostname = sys.hostname() --owm


	-- s system,a arch,r ram owm
	local s,a,r = sys.sysinfo() --owm
	root.hardware = s --owm
	

	root.firmware = {
	--	luciname=version.luciname,
	--	luciversion=version.luciversion,
	--	distname=version.distname,
		name=version.distname, --owm
	--	distversion=version.distversion,
		revision=version.distversion --owm
	}

	root.freifunk = {}
	cursor:foreach("freifunk", "public", function(s)
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

	cursor:foreach("system", "system", function(s) --owm
		root.latitude = tonumber(s.latitude) --owm
		root.longitude = tonumber(s.longitude) --owm
	end)

	local devices = {}
	cursor:foreach("wireless", "wifi-device",function(s)
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

	local interfaces = {}
	cursor:foreach("wireless", "wifi-iface",function(s)
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
		local iwinfo = luci.sys.wifi.getiwinfo(s.ifname)
		if iwinfo then
			local _, f
			for _, f in ipairs({
			"channel", "txpower", "bitrate", "signal", "noise",
			"quality", "quality_max", "mode", "ssid", "bssid", "encryption", "ifname"
			}) do
				interfaces[#interfaces][f] = iwinfo[f]
			end
		end
	end)

	root.interfaces = {} --owm
	cursor:foreach("network", "interface",function(vif)
		if 'lo' == vif.ifname then
			return
		end
		local name = vif['.name']
		root.interfaces[#root.interfaces+1] =  vif
		root.interfaces[#root.interfaces].name = name --owm
		root.interfaces[#root.interfaces].ifname = vif.ifname --owm
		root.interfaces[#root.interfaces].ipv4Addresses = {vif.ipaddr} --owm
		root.interfaces[#root.interfaces].ipv6Addresses = {vif.ip6addr} --owm
		root.interfaces[#root.interfaces].type = 'ethernet' --owm
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

		for i,v in ipairs(interfaces) do
			if v['network'] == name then
				root.interfaces[#root.interfaces].type = 'wifi' --owm
				for ii,vv in ipairs(devices) do
					if v['device'] == vv.name then
						v.wirelessdevice = vv
					end
				end
				root.interfaces[#root.interfaces].mode = v.mode
				root.interfaces[#root.interfaces].encryption = v.encryption
				root.interfaces[#root.interfaces].access = 'free'
				root.interfaces[#root.interfaces].accessNote = "everyone is welcome!"
				root.interfaces[#root.interfaces].channel = v.wirelessdevice.channel
				root.interfaces[#root.interfaces].txpower = v.wirelessdevice.txpower
				root.interfaces[#root.interfaces].bssid = v.bssid
				root.interfaces[#root.interfaces].ssid = v.ssid
				root.interfaces[#root.interfaces].wireless = v --owm
			end
		end

	end)

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
	local neighbors = fetch_olsrd_neighbors(root.interfaces)
	local arptable = sys.net.arptable()
	local devices  = ntm:get_wifidevs()
	local assoclist = {}
	local has_iwinfo = pcall(require, "iwinfo")
	for _, dev in ipairs(devices) do
		for _, net in ipairs(dev:get_wifinets()) do
			assoclist[#assoclist+1] = net.iwinfo.assoclist
		end
	end

	--TODO read neighbors discovery cache for mac,ipv6 table
	for _, arpt in ipairs(arptable) do
		local mac = arpt['HW address']:lower()
		local ip = arpt['IP address']
		for i, neigh in ipairs(neighbors) do
			if neigh['destAddr4'] == ip then
				neighbors[i]['arp'] = arpt
				neighbors[i]['arp']['HW address'] = showmac(mac)
				neighbors[i]['mac'] = showmac(mac)
				neighbors[i]['dev'] = arpt['Device']
				neighbors[i]['mask'] = arpt['Mask']
				neighbors[i]['flags'] = arpt['Flags']
				neighbors[i]['hwtype'] = arpt['HW type']
			end
		end
	end
	for _, val in ipairs(assoclist) do
		for assocmac, assot in pairs(val) do
			for i, neigh in ipairs(neighbors) do
				local mac = assocmac:lower()
				if neigh['mac'] == showmac(mac) then
					neighbors[i]['wifi'] = assot
					neighbors[i]['signal'] = assot.signal
					neighbors[i]['noise'] = assot.noise
				end
			end
		end
	end
	root.neighbors = neighbors

	root.olsr = fetch_olsrd()

	http.prepare_content("application/json")
	ltn12.pump.all(json.Encoder(root):source(), http.write)
end

