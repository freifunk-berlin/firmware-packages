local sys = require "luci.sys"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()

module("luci.tools.freifunk.freifunk-berlin", package.seeall)

-- Helpers --
-- Removes a listentry, handles real and pseduo lists transparently
function remove_list_entry(value, entry)
	if type(value) == "nil" then
		return nil
	end

	local result = type(value) == "table" and value or util.split(value, " ")
	local key = util.contains(result, entry)

	while key do
		table.remove(result, key)
		key = util.contains(result, entry)
	end

	result = type(value) == "table" and result or table.concat(result, " ")
	return result ~= value and result
end


function logger(msg, type, prio)
	sys.exec("logger -t "..type.." -p "..prio.." '"..msg.."'")
end

--Merge the options of multiple config files into a table.
--
--configs: an array of strings, each representing a config file.  
--  The order is important since  the first config file is read, 
--  then the following.  Any options in the following config files
--  overwrite the values of any previous config files. 
--  e.g. {"freifunk", "profile_berlin"}
--sectionType: the section type to merge. e.g. "defaults"
--sectionName: the section to merge. e.g. "olsrd"
function getMergedConfig(configs, sectionType, sectionName)
	local data = {}
	for i, config in ipairs(configs) do
		uci:foreach(config, sectionType,
			function(s)
				if s['.name'] == sectionName then
					for key, val in pairs(s) do
						if string.sub(key, 1, 1) ~= '.' then
							data[key] = val
						end
					end
				end
			end)
		end
	return data
end

function mergeInto(config, section, options)
	local s = uci:get_first(config, section)
	if (section) then
		uci:tset(config, s, options)
	else
		uci:section(config, section, nil, options)
	end
	uci:save(config)
end
