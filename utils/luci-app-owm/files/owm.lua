#!/usr/bin/lua

require("luci.util")
require("luci.model.uci")
require("luci.sys")
require("nixio.fs")
require("luci.httpclient")

-- Init state session
local uci = luci.model.uci.cursor_state()
local owm = require "luci.owm"
local json = require "luci.json"
local lockfile = "/var/run/owm.lock"
local hostname

--function db_put(uri,body)
function db_put(owm_api,hostname,suffix,body)
	local httpc = luci.httpclient
	local uri_update = owm_api.."/update_node/"..hostname.."."..suffix
	
	local options = {
		method = "PUT",
		body = body,
		headers = {
			["Content-Type"] = "application/json",
		},
	}
	
	local response, code, msg = httpc.request_to_buffer(uri_update, options)

	if code == 201 then
		print("update Doc  Statuscode: "..code.." "..uri_update.." ("..msg..")")
	elseif code then
		print("fail   Doc  Statuscode: "..code.." "..uri_update.." ("..msg..")")
	end
end


function lock()
	if nixio.fs.access(lockfile) then
		local timediff = os.time() - nixio.fs.stat(lockfile, "mtime")
		if timediff < 3600 then
			print(lockfile.." exists, time since lock: "..timediff)
			os.exit()
		end
	else
		os.execute("lock "..lockfile)
	end
end

function unlock()
	os.execute("lock -u "..lockfile)
	os.execute("rm -f "..lockfile)
end

lock()

uci:foreach("system", "system", function(s) --owm
	hostname = s.hostname
end)

local owm_api = uci:get("freifunk", "community", "owm_api") or "http://api.openwifimap.net/"
local cname = uci:get("freifunk", "community", "name") or "freifunk"
local suffix = uci:get("freifunk", "community", "suffix") or uci:get("profile_" .. cname, "profile", "suffix") or "olsr"
local body = json.encode(owm.get())

if arg[1]=="--dry-run" then
	print(body)
	unlock()
	return
end

if type(owm_api)=="table" then
	for i,v in ipairs(owm_api) do 
		local owm_api = v
		db_put(owm_api,hostname,suffix,body)
	end
else
	db_put(owm_api,hostname,suffix,body)
end

unlock()

