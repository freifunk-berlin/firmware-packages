module("luci.controller.chat", package.seeall)

local sys 	= require "luci.sys"
local fs 	= require "luci.fs"
local uci 	= require "luci.model.uci".cursor()
local http 	= require "luci.http"
local util 	= require "luci.util"

function index()
	entry({"freifunk", "chat"}, template("chat"), "Chat", 100)
end

