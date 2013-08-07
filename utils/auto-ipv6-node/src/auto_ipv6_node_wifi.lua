#!/usr/bin/env lua

local sys = require "luci.sys"
local fs = require "luci.fs"
local utl = require "luci.util"
local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local json = require "luci.json"
local string = require "string"
local ntm = require "luci.model.network"
local profiles = "/etc/config/profile_"
local ready = false

function iwscanlist(ifname,times)
	local iw = sys.wifi.getiwinfo(ifname)
	local i, k, v
	local l = { }
	local s = { }

	for i = 1, times do
		for k, v in ipairs(iw.scanlist or { }) do
			if not s[v.bssid] then
				l[#l+1] = v
				s[v.bssid] = ""
			end
		end
	end

	return l
end

function get_profiles()
	local list = fs.glob(profiles .. "*") or {}
	local pft = {}
	for k,v in ipairs(list) do
		pft[#pft+1] = {}
		local n = string.gsub(v, profiles, "")
		pft[#pft].uciname = n
		pft[#pft].name = uci:get_first("profile_"..n, "community", "name") or ""
		pft[#pft].ssid = uci:get_first("profile_"..n, "community", "ssid") or ""
		pft[#pft].bssid = string.upper(uci:get_first("profile_"..n, "defaults", "bssid") or "")
		pft[#pft].channel = uci:get_first("profile_"..n, "defaults", "channel") or ""
	end
	return pft
end

function get_wconf(tbl,pft)
	local wconf = {}
	for i, net in ipairs(tbl) do
		if net.mode == "Ad-Hoc" then
			print(net.quality,net.bssid,net.channel,net.signal.." dB",net.quality,net.quality_max.." max")
			wconf.mode = "adhoc"
			wconf.ssid = net.ssid
			wconf.bssid = net.bssid
			wconf.channel = net.channel
			wconf.profile = "berlin"
			for i, profile in ipairs(pft) do
				--print("profile"..profile.ssid,net.ssid)
--				if net.ssid == profile.ssid then
--					print("ssid profile "..profile.uciname,"net "..net.ssid,net.bssid)
--				end
			end
			for i, profile in ipairs(pft) do
				--print("profile: "..profile.bssid.."net: "..net.bssid)
--				if net.bssid == profile.bssid then
--					print("bssid profile "..profile.uciname,"net "..net.ssid,net.bssid)
--				end
			end
			for i, profile in ipairs(pft) do
				--print("profile "..profile.bssid,"net "..net.bssid)
				local pssid = string.gsub(profile.ssid,"%..*","")
				local nssid = string.gsub(net.ssid,"%..*","")
--				if nbssid == pbssid then
--					print("ssid profile %..*:[] "..profile.uciname,"profile "..profile.ssid,"net "..net.ssid)
--				end
			end
			for i, profile in ipairs(pft) do
				--print("profile "..profile.bssid,"net "..net.bssid)
				local pbssid = string.gsub(profile.bssid,"%x%x:","",1)
				local nbssid = string.gsub(net.bssid,"%x%x:","",1)
--				if nbssid == pbssid then
--					print("bssid profile %x%x:[] "..profile.uciname,"profile"..profile.bssid,"net "..net.bssid)
--				end
			end
			return  wconf
		end
	end
	return wconf
end


local profiles = get_profiles()
ntm.init(uci)
local devices = ntm:get_wifidevs()
local dev
for _,dev in ipairs(devices) do
	dev:set("disabled", nil)
	for _, net in ipairs(dev:get_wifinets()) do
		print(dev:name())
		local ifc = net:get_interface()
		print(ifc.ifname)
		local scan = iwscanlist(ifc.ifname,3)
		table.sort(scan, function(a, b) 
			return tonumber(a["quality"]) > tonumber(b["quality"])
		end)
		local wificonfig = get_wconf(scan,profiles)
		print(wificonfig.profile,wificonfig.ssid,wificonfig.bssid,wificonfig.channel)
		external = "profile_"..wificonfig.profile
		dev:set("channel", wificonfig.channel)
		dev:set("noscan",true)
		dev:set("distance",1000)
		net:set("ssid",wificonfig.ssid)
		net:set("bssid",wificonfig.bssid)
		net:set("mode",wificonfig.mode or "adhoc")
		net:set("network","wireless0")
		ntm:save("wireless")

		uci:section("network","interface","wireless0", {
			proto = "static",
			ip6assign = 64
		})
		uci:save("network")
		uci:commit("network")

		--local rifn = uci:get_list("6relayd","default","network") or {}
		local rifn = {}
		table.insert(rifn,"wireless0")
		table.insert(rifn,"lan")
		uci:set_list("6relayd","default","network",rifn)
		uci:save("6relayd")

		local community = uci:get_all(external, "profile")
		uci:tset("freifunk", "community", community)
		uci:set("freifunk", "community", "name", wificonfig.profile)
		uci:save("freifunk")
		uci:commit("freifunk")

		local rand = sys.exec("head -n 1 /dev/urandom 2>/dev/null | md5sum | cut -b 1-4")
		local new_hostname = "OpenWrt-"..rand
		uci:foreach("system", "system",
			function(s)
				-- Make set timzone and zonename
				uci:set("system", s[".name"], "zonename", "Europe/Berlin")
				uci:set("system", s[".name"], "timezone", 'CET-1CEST,M3.5.0,M10.5.0/3')
				-- Set hostname
				uci:set("system", s[".name"], "hostname", new_hostname)
				sys.hostname(new_hostname)
				-- Set hostname
				uci:set("system", s[".name"], "latitude", community.latitude)
				uci:set("system", s[".name"], "longitude", community.longitude)
			end)
		uci:save("system")
		uci:commit("system")

		uci:delete_all("olsrd", "olsrd")
		local olsrbase = uci:get_all("freifunk", "olsrd") or {}
		utl.update(olsrbase, uci:get_all(external, "olsrd") or {})
		olsrbase.IpVersion = "6"
		olsrbase.LinkQualityAlgorithm = "etx_ffeth"
		olsrbase.NatThreshold = nil
		uci:section("olsrd", "olsrd", nil, olsrbase)
		local olsrifbase = uci:get_all("freifunk", "olsr_interface") or {}
		utl.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
		olsrifbase.Ip4Broadcast = nil
		uci:section("olsrd", "InterfaceDefaults", nil, olsrifbase)
		uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_jsoninfo.so.0.0"})
		uci:section("olsrd", "LoadPlugin", nil, {
			library = "olsrd_jsoninfo.so.0.0",
			ignore = 0,
			accept = "::"
		})
		uci:delete_all("olsrd", "Interface")
		local olsrifbase = {}
		olsrifbase.interface = "wireless0"
		olsrifbase.ignore = "0"
		uci:section("olsrd", "Interface", nil, olsrifbase)
		local olsrifbase = {}
		olsrifbase.interface = "lan"
		olsrifbase.ignore = "0"
		uci:section("olsrd", "Interface", nil, olsrifbase)
		uci:save("olsrd")
		uci:commit("olsrd")
		ready = true
	end
end

if ready then
	luci.sys.call("(/etc/init.d/network restart) >/dev/null 2>/dev/null")
	luci.sys.call("(/etc/init.d/olsrd restart) >/dev/null 2>/dev/null")
	luci.sys.call("(/etc/init.d/6relayd restart) >/dev/null 2>/dev/null")
end

