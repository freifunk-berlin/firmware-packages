local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local tools = require "luci.tools.freifunk.assistent.ffwizard"

f = SimpleForm("ffwizward", "", "")
f.submit = "Next"
f.cancel = "Skip"
f.reset = false

css = f:field(DummyValue, "css", "")
css.template = "freifunk/assistent/snippets/css"

hostname = f:field(Value, "hostname", "Knoten Name", "")
hostname.datatype = "hostname"
function hostname.cfgvalue(self, section)
	return uci:get_first("system", "system","hostname") or sys.hostname()
end

mail = f:field(Value, "mail", "E-Mail", "")
mail.datatype = "string"
function mail.cfgvalue(self, section)
	return uci:get("freifunk", "contact", "mail")
end

location = f:field(Value, "location", "Standort", "")
location.datatype = "string"
function location.cfgvalue(self, section)
	return uci:get_first("system", "system", "location") or uci:get("freifunk", "contact", "location")
end

lat = f:field(Value, "lat", "geographischer Breitengrad", "")
lat.datatype = "float"
function lat.cfgvalue(self, section)
	return uci:get_first("system", "system","latitude")
end

lon = f:field(Value, "lon", "geograpischer Längengrad", "")
lon.datatype = "float"
function lon.cfgvalue(self, section)
	return uci:get_first("system", "system","longitude")
end


generalinfo = f:field(DummyValue,"","")
generalinfo.template = "freifunk/assistent/snippets/generalInfo"

main = f:field(DummyValue, "config", "", "")
main.forcewrite = true
function main.parse(self, section)
	local fvalue = "1"
	if self.forcewrite then
		self:write(section, fvalue)
	end
end
function main.write(self, section, value)
	
	uci:set("freifunk", "contact", "mail", mail:formvalue(section))
	uci:set("freifunk", "contact", "location",location:formvalue(section))

	local latval
	local lonval
	if (lat:formvalue(section) and lon:formvalue(section)) then	
		latval = tonumber(lat:formvalue(section)) 
		lonval = tonumber(lon:formvalue(section))
	end

	--SYSTEM CONFIG
	uci:foreach("system", "system",
		function(s)
			uci:set("system", s[".name"], "cronloglevel", "10")
			uci:set("system", s[".name"], "zonename", "Europe/Berlin")
			uci:set("system", s[".name"], "timezone", 'CET-1CEST,M3.5.0,M10.5.0/3')
			uci:set("system", s[".name"], "hostname", hostname:formvalue(section))	
			if (lonval and latval) then
				uci:set("system", s[".name"], "latlon",string.format("%.15f %.15f", latval, lonval))
				uci:set("system", s[".name"], "latitude",string.format("%.15f", latval))
				uci:set("system", s[".name"], "longitude",string.format("%.15f", lonval))
			else
				uci:delete("system", s[".name"], "latlon")
				uci:delete("system", s[".name"], "latitude")            
				uci:delete("system", s[".name"], "longitude")	
			end
			uci:set("system", s[".name"], "location",location:formvalue(section))
		
		end)
		
		
	uci:save("system")
	uci:save("freifunk")
end

function f.handle(self, state, data)
        if state == FORM_VALID then
        	luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/decide"))
        end
end

--don't know how to trigger reset button, so I use skip button instead
function f.on_cancel()
        tools.logger("skip general settings")
        luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/decide"))
end
                                                                                                                        

 
return f
 
 
