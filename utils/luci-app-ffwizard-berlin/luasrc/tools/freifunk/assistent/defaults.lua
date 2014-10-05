module("luci.tools.freifunk.assistent.defaults", package.seeall)

function bandwidths()
  return {
		dsl1000 = {name= "DSL 1000", up= "0.128", down= "1.024" },
    dsl2000 = { name= "DSL 2000", up= "0.192", down= "2.048" },
    dsl6000 = { name= "DSL 6000", up= "0.512", down= "6.016" },
    dsl16000 = { name= "DSL 16000", up= "1.024", down= "16" },
		dsl1000alt = {name= "DSL 1000 (2004)", up= "0.128", down= "0.768" },
    dsl2000alt = { name= "DSL 2000 (2004)", up= "0.192", down= "1.536" },
    dsl3000 = { name= "DSL 3000", up= "0.384", down= "3.072" },
    dsl2000upgrade = { name= "DSL 2000 (upgrade)", up= "0.384", down= "2.048" },
    dsl3000upgrade = { name= "DSL 3000 (upgrade)", up= "0.512", down= "3.072" },
    vdsl25 = { name= "VDSL 25", up= "25", down= "25" },
    vdsl50 = { name= "VDSL 50", up= "50", down= "50" },
    fiber1000 = { name= "Fiber 100", up= "50", down= "100" },
    kabel10 = { name= "Kabel I&T 10", up= "0,6", down= "50" },
    kabel25 = { name= "Kabel I&T 25", up= "1", down= "25" },
    kabel50 = { name= "Kabel I&T 50", up= "2", down= "50" },
    kabel100 = { name= "Kabel I&T 100", up= "6", down= "100" }
  }
end
