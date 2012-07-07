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
require("luci.tools.webadmin")
m = Map("linknx", "EIB Typen", "EIB/KNX Typen")

s = m:section(TypedSection, "typeexpr", "Type")
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"
s.sortable = true

en = s:option(Flag, "disable", "Disable")
en.optional = true
tpex = s:option(Value, "typeexpr", "Expression/Ausdruck/Suchmuster")
svc = s:option(Value, "type", "EIB Typ")
svc.rmempty = true
svc:value("1.001")
svc:value("7.xxx")
svc:value("9.xxx")
svc:value("5.001")
svc:value("3.007")
svc:value("20.102")
co = s:option(Value, "comment", "Comment")
iv = s:option(Value, "init", "Initial Value")

return m
