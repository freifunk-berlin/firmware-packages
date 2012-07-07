--[[
LuCI - Lua Configuration Interface

Copyright 2012 Patrick Grimm <patrick@lunatiki.de>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

require("luci.sys")
require("luci.util")
require("luci.model.uci")
require("luci.tools.webadmin")
require("luci.statistics.rrdtool")
require("nixio")

local larg = arg
local larg0 = arg[0]
local larg1 = arg[1]
local larg2 = arg[2]
local larg3 = arg[3]
if not larg1 then
	return
end


function readval(txt)
	uds:send("<read><object id="..txt.."/></read>\r\n\4")
	ret = uds:recv(8192) or ''
	if string.find(ret, "success") then
		ret = string.gsub(ret,'.*success..','')
		ret = string.gsub(ret,'..read.*','')
		if string.find(txt, '_hw_') then
			if string.find(ret, '%.') then
				ret = round(ret)
			end
		end
		if string.find(ret, 'on') then
			ret = '1'
		elseif string.find(ret, 'off') then
			ret = '0'
		end
		if string.find(txt, 'stat_dw_1') then
			local retbit=tonumber(ret) or 1
			local ret_text=''
			if retbit >= 128 then
				ret_text=ret_text.." Frostalarm"
				retbit=retbit-128
			end
			if retbit >= 64 then
				ret_text=ret_text.." Totzone"
				retbit=retbit-64
			end
			if retbit >= 32 then
				ret_text=ret_text.." Heizen"
				retbit=retbit-32
			else
				ret_text=ret_text.." Kühlen"
			end
			if retbit >= 16 then
				ret_text=ret_text.." gesperrt"
				retbit=retbit-16
			end
			if retbit >= 8 then
				ret_text=ret_text.." Frost"
				retbit=retbit-8
			end
			if retbit >= 4 then
				ret_text=ret_text.." Nacht"
				retbit=retbit-4
			end
			if retbit >= 2 then
				ret_text=ret_text.." Standby"
				retbit=retbit-2
			end
			if retbit >= 1 then
			        ret_text=ret_text.." Komfort"
			end
         		ret=ret_text
		end
		if string.find(txt, 'stat_dw_2') then
			local retbit=tonumber(ret) or 1
			local ret_text=ret
			if retbit >= 128 then
				ret_text=ret_text.." Taupunktbetrieb"
				retbit=retbit-128
			end
			if retbit >= 64 then
				ret_text=ret_text.." Hitzeschutz"
				retbit=retbit-64
			end
			if retbit >= 32 then
				ret_text=ret_text.." Zusatzstufe"
				retbit=retbit-32
			end
			if retbit >= 16 then
				ret_text=ret_text.." Fensterkontakt"
				retbit=retbit-16
			end
			if retbit >= 8 then
				ret_text=ret_text.." Präsenztaste"
				retbit=retbit-8
			end
			if retbit >= 4 then
				ret_text=ret_text.." Präsenzmelder"
				retbit=retbit-4
			end
			if retbit >= 2 then
				ret_text=ret_text.." Komfortverlängerung"
				retbit=retbit-2
			end
			if retbit >= 1 then
			        ret_text=ret_text.." Normal"
			else
				ret_text=ret_text.." Zwangs-Betriebsmodus"
			end
         		ret=ret_text
		end
		return ret
	elseif string.find(ret, 'read status=.error') then
		return '1'
	else
		return '2'
	end
end

function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

local sys = require "luci.sys"
--local uci = require "luci.model.uci"
local uci = luci.model.uci.cursor()
local uci_state = luci.model.uci.cursor_state()
--local cursor = uci.cursor_state()
local util = require "luci.util"
local http = require "luci.http"
local json = require "luci.json"
local ltn12 = require "luci.ltn12"
local version = require "luci.version"
local webadmin = require "luci.tools.webadmin"

local apgroup = {}
local apgroup_i = 0
local el = {}
local el_i = 0
local el1 = {}
local first1 = true
local first2 = true
local first3 = true

if larg1 == 'structure' then
	uci:foreach("linknx_group", "group", function(s)
		if not s.pgroup then
			local pgroupname = s.name
			el_i = el_i + 1
			el[el_i] = {}
			el[el_i].name = pgroupname
			el[el_i].comment = s.comment
			uci:foreach("linknx_group", "group", function(t)
				if t.pgroup == pgroupname then
					el_i = el_i + 1
					el[el_i] = {}
					el[el_i].name = t.name
					el[el_i].room = t.name
					el[el_i].stage = t.pgroup
					el[el_i].text = t.comment
					el[el_i].statlist = {}
					local host = uci:get( "luci_statistics", "collectd", "Hostname" ) or luci.sys.hostname()
					host = host..'_'..t.pgroup
					local plugin = "ezr"
					local inst = t.name
					local spans = luci.util.split( uci:get( "luci_statistics", "collectd_rrdtool", "RRATimespans" ), "%s+", nil, true )
					for i, span in ipairs( spans ) do
						local opts = { host = host }
						local graph = luci.statistics.rrdtool.Graph( luci.util.parse_units( span ), opts )
						local hosts = graph.tree:host_instances()
						local is_index = false
						local images = { }
						for i, img in ipairs( graph:render( plugin, inst, is_index ) ) do
							table.insert( images, graph:strippngpath( img ) )
							images[images[#images]] = inst
						end
						-- deliver json image list
						for i, img in ipairs(images) do
							local imgurl = luci.dispatcher.build_url("linknx", "graph", plugin).."?img="..img.."&host="..host
							local statimg = {title = "Title1" , html = imgurl}
							el[el_i].statlist[#el[el_i].statlist+1] = statimg
						end
					end
				end
			end)
		end
	end)
elseif larg1 == 'almlist' then
	uci:foreach("linknx_group", "group", function(g)
		uci_state:load("linknx_varlist_"..g.name)
		uci_state:foreach("linknx_varlist_"..g.name, "pvar", function(s)
			if s.event=='alarm' and s.ontime then
				if tonumber(s.offtime) == 0 or s.ack=="unack" then
					el_i = el_i + 1
					el[el_i] = {}
					el[el_i].varName = s.name
					el[el_i].value = s.value or '0'
					el[el_i].group = s.group
					el[el_i].commentName = s.comment
					el[el_i].onTime = s.ontime
					el[el_i].offTime = s.offtime
					el[el_i].ackTime = s.acktime
					el[el_i].lastTime = s.lasttime
					el[el_i].ack = s.ack
				end
			end
		end)
	end)
else
	local socket_tagnames = {}
	local socket_tagnames_i = 1
	uci:foreach("linknx", "socket", function(s)
		if s.cmd then
			socket_tagnames[socket_tagnames_i] = s.tagname
			socket_tagnames_i = socket_tagnames_i+1
		end
	end)

	local nixio	= require "nixio"
	uds = nixio.socket('unix', 'stream', none)
	if uds:connect('/var/run/linknx.sock') then
		has_xmlsocket = true
	end
	
	local linknx_tagnames = {}
	local linknx_tagnames_i = 1
	uci:foreach("linknx", "daemon", function(s)
		if s.esf then
			if nixio.fs.access(s.esf) then
				linknx_tagnames[linknx_tagnames_i] = s.tagname
				linknx_tagnames_i = linknx_tagnames_i+1
			end
		end
	end)

	uci_state:foreach("linknx_varlist_"..larg1, "pvar", function(s)
		if s.group == larg1 then
			if larg2 then
				if string.find(s.name, larg2) then
					if larg3 then
						if string.find(s.name, larg3) then
							el_i = el_i + 1
							el[el_i] = {}
							el[el_i].label = s.comment
							el[el_i].id = s.name
							el[el_i].group = s.group
							for i, ss in ipairs(linknx_tagnames) do
								if ss == s.tagname then
									el[el_i].value = has_xmlsocket and readval(s.name) or '0'
									el[el_i].tagname = s.tagname
								end
							end
						end
					else
						el_i = el_i + 1
						el[el_i] = {}
						el[el_i].label = s.comment
						el[el_i].id = s.name
						el[el_i].group = s.group
						for i, ss in ipairs(linknx_tagnames) do
							if ss == s.tagname then
								el[el_i].value = has_xmlsocket and readval(s.name) or '0'
								el[el_i].tagname = s.tagname
							end
						end
					end
				end
			else
				el_i = el_i + 1
				el[el_i] = {}
				el[el_i].label = s.comment
				el[el_i].id = s.name
				el[el_i].group = s.group
				for i, ss in ipairs(linknx_tagnames) do
					if ss == s.tagname then
						el[el_i].value = has_xmlsocket and readval(s.name) or '0'
						el[el_i].tagname = s.tagname
					end
				end
			end
		end
	end)
	if has_xmlsocket then
		uds:close()
	end
end

--if has_xmlsocket then
--	uds:close()
--end

http.prepare_content("application/json")
ltn12.pump.all(json.Encoder(el):source(), http.write)

