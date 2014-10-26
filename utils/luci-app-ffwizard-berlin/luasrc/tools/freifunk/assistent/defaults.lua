module("luci.tools.freifunk.assistent.defaults", package.seeall)

function bandwidths()
  return {
    dsl2000 = { name= "DSL 2000", up= "0.192", down= "2.048" },
    dsl6000 = { name= "DSL 6000", up= "0.512", down= "6.016" },
    dsl16000 = { name= "DSL 16000", up= "1.024", down= "16" },
    vdsl25 = { name= "VDSL 25", up= "25", down= "25" },
    vdsl50 = { name= "VDSL 50", up= "50", down= "50" },
    kabel25 = { name= "Kabel I&T 25", up= "1", down= "25" },
    kabel50 = { name= "Kabel I&T 50", up= "2", down= "50" },
    kabel100 = { name= "Kabel I&T 100", up= "6", down= "100" },
    fiber1000 = { name= "Fiber 100", up= "50", down= "100" }
  }
end
