local uci = require "luci.model.uci".cursor()
local tools = require "luci.tools.freifunk.assistent.ffwizard"

f = SimpleForm("ffvpn","","")
f.submit = "Next"
f.cancel = "Back"
f.reset = false


css = f:field(DummyValue, "css", "")
css.template = "freifunk/assistent/snippets/css"

local cert = f:field(FileUpload, "cert", translate("Local Certificate"),"freifunk_client.crt")
cert.default="/etc/openvpn/freifunk_client.crt"
cert.rmempty = false
cert.optional = false

local key = f:field(FileUpload, "key", translate("Local Key"),"freifunk_client.key")
key.default="/etc/openvpn/freifunk_client.key"
key.rmempty = false
key.optional = false

apinfo = f:field(DummyValue, "apinfo", "")                                                          
apinfo.template = "freifunk/assistent/snippets/vpninfo"                                              
                                                                                                    

main = f:field(DummyValue, "openvpnconfig", "", "") 
main.forcewrite = true

function main.parse(self, section)
	local fvalue = "1"
	if self.forcewrite then 
		self:write(section, fvalue) 
	end 
end 

function main.write(self, section, value)

	uci:set("freifunk", "wizard", "sharenet", 1)
	--für den alten assistenten
	uci:set("freifunk", "wizard", "wan_security", 1)
	uci:set("freifunk", "wizard", "wan_input_accept", 1)

		
	uci:section("openvpn", "openvpn", "ffvpn", {
 		client='1',
	        nobind='1',
        	proto='udp',
	        dev='ffvpn',
       	 	dev_type='tun',
	        persist_key='1',
        	ns_cert_type='server',
	        comp_lzo='no',
        	script_security='2',
	        cipher='none',
        	ca='/etc/openvpn/freifunk-ca.crt',
	        status='/var/log/openvpn-status-ffvpn.log',
        	up='/etc/openvpn/ffvpn-up.sh',
	        route_nopull='1',
        	persist_tun='0',
	        enabled='1',
	        cert='/lib/uci/upload/cbid.ffvpn.1.cert',
	        key='/lib/uci/upload/cbid.ffvpn.1.key'
	})

	uci:save("openvpn")
	uci:set_list ("openvpn", "ffvpn", "remote", {'77.87.48.10 1194 udp','78.41.116.65 1194 udp'})


	uci:section("network", "interface", "tunl0", {
		proto = "none",
		ifname = "tunl0"
	})

	tools.firewall_zone_add_interface("freifunk", "tunl0")
 	
 	uci:save("freifunk")
	uci:save("network")
	uci:save("firewall")


	-- I need to commit this here, don't know why I can not do this in apply changes
	uci:commit("openvpn")

end

function f.handle(self, state, data)                                                                                     
        if state == FORM_VALID then                                                                                      
	        luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/wireless"))                 
        end                                                                                                              
end 

function f.on_cancel()
	luci.http.redirect(luci.dispatcher.build_url("admin/freifunk/assistent/decide"))
end

return f
