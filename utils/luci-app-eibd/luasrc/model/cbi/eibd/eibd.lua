--[[
LuCI - Lua Configuration Interface

Copyright 2012 Patrick Grimm <patrick@lunatiki.de>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

require("luci.tools.webadmin")
m = Map("eibd", "EIB Server", "EIB/KNX Server for RS232 USB EIB/IP Routing EIB/IP Tunnelling")

s = m:section(TypedSection, "eibinterface", "EIB Interface")
s.addremove = true
s.anonymous = true

s:option(Flag, "disable", "Disable").optional = true

svc = s:option(ListValue, "interface", "Interface Name")
svc.rmempty = true
svc:value("")
svc:value("usb")
svc:value("ip")

s:option(Flag, "Discovery", "Discover for ETS").optional = true
s:option(Flag, "Server", "Server for ETS").optional = true
s:option(Flag, "Tunnelling", "Tunnelling for ETS").optional = true
s:option(Value, "listentcp", "Listen tcp port").optional = true
s:option(Value, "listenlocal", "Socket File").optional = true
s:option(Value, "eibaddr", "EIB HW Addr").optional = true
s:option(Value, "daemon", "Logfile").optional = true
s:option(Value, "trace", "Debug level").optional = true
s:option(Value, "pidfile", "PID File").optional = true

return m
