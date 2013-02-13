#!/usr/bin/lua

require("luci.util")
require("luci.model.uci")
require("luci.sys")
require("luci.fs")
require("luci.httpclient")

-- Init state session
local uci = luci.model.uci.cursor_state()
local owm = require "luci.owm"
local json = require "luci.json"
local lockfile = "/var/run/owm.lock"
local hostname

function db_put(uri,body)
	local httpc = luci.httpclient
	local etag = ""
	local options = {
		method = "HEAD",
	}
	
	local code,response, msg, csock = httpc.request_raw(uri, options)
	
	if not response or not code then
		print("get ETag fail "..uri)
	else
		if code == 404 then
			print("new    ETag Statuscode: "..code.." "..uri)
			etag = ""
		elseif code == 200 then
			etag = response.headers['ETag'] or ""
			etag = string.gsub(etag, '\"', '')
			print("get    ETag Statuscode: "..code.." "..uri.." "..etag)
		elseif code then
			print("fail   ETag Statuscode: "..code.." "..uri)
		end
	end
	
	local options = {
		method = "PUT",
		body = body,
		headers = {
			["Content-Type"] = "application/json",
		},
	}
	
	if etag == "" then
		local response, code, msg = httpc.request_to_buffer(uri, options)
	else
		local response, code, msg = httpc.request_to_buffer(uri.."?rev="..etag, options)
	end
	
	if not response or not code then
		print("fail "..uri)
	else
		if code == 404 then
			print("new    Doc  Statuscode: "..code.." "..uri)
		elseif code == 200 then
			print("update Doc  Statuscode: "..code.." "..uri)
		elseif code then
			print("fail   Doc  Statuscode: "..code.." "..uri)
		end
	end
end


function lock()
	if luci.fs.isfile(lockfile) then
		print(lockfile.." exist")
		os.exit()
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

local mapserver = uci:get("freifunk", "community", "mapserver") or "http://openwifimap.net/openwifimap/"
local cname = uci:get("freifunk", "community", "name") or "freifunk"
local suffix = uci:get("freifunk", "community", "suffix") or uci:get("profile_" .. cname, "profile", "suffix") or "olsr"
local body = json.encode(owm.get())

if type(mapserver)=="table" then
	for i,v in ipairs(mapserver) do 
		local uri = v.."/"..hostname.."."..suffix
		db_put(uri,body)
	end
else
	local uri = mapserver.."/"..hostname.."."..suffix
	db_put(uri,body)
end

unlock()

