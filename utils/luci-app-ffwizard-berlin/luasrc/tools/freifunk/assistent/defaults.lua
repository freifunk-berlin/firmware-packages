module("luci.tools.freifunk.assistent.defaults", package.seeall)

function bandwidths()
  return {
		adsl = {name= "ADSL", up= "1", down= "8" },
    adsl2 = { name= "ADSL2", up= "1", down= "24" },
    vdsl = { name= "VDSL", up= "10", down= "50" },
    vdsl2 = { name= "VDSL2", up= "200", down= "200" }
  }
end
