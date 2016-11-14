#!/bin/sh

. /usr/share/libubox/jshn.sh

log_olsrd() {
	logger -s -t ffwizard_olsrd "$@"
}

setup_olsrd() {
	local cfg=$1
	json_init
	json_load "$CONFIG_JSON" || exit 1
	json_select config

	json_select ip

  # add routing tables
  tables="/etc/iproute2/rt_tables"
  test -d /etc/iproute2/ || mkdir -p /etc/iproute2/
  grep -q "111 olsr" $tables || echo "111 olsr" >> $tables
  grep -q "112 olsr-default" $tables || echo "112 olsr-default" >> $tables
  grep -q "113 olsr-tunnel" $tables || echo "113 olsr-tunnel" >> $tables

  # reset olsrd config
  uci import olsrd <<EOF
EOF

  # set olsrd defaults
  OLSRD="$(uci add olsrd olsrd)"
  uci set olsrd.$OLSRD.IpVersion=4
  uci set olsrd.$OLSRD.FIBMetric=flat
  uci set olsrd.$OLSRD.AllowNoInt=yes
  uci set olsrd.$OLSRD.TcRedundancy=2
  uci set olsrd.$OLSRD.NatThreshold=0.75
  uci set olsrd.$OLSRD.LinkQualityAlgorithm=etx_ff
  uci set olsrd.$OLSRD.SmartGateway=yes
  uci set olsrd.$OLSRD.SmartGatewayThreshold=50
  uci set olsrd.$OLSRD.Pollrate=0.025
  # TODO: re-enable when policy routing is back in a sane form
  #uci set olsrd.$OLSRD.RtTable=111
  #uci set olsrd.$OLSRD.RtTableDefault=112
  #uci set olsrd.$OLSRD.RtTableTunnel=113
  #uci set olsrd.$OLSRD.RtTableTunnelPriority=100000
  #uci set olsrd.$OLSRD.RtTableDefaultOlsrPriority=20000

  # set InterfaceDefaults parameters
  INTERFACES="$(uci add olsrd InterfaceDefaults)"
  uci set olsrd.$INTERFACES.MidValidityTime=500.0
  uci set olsrd.$INTERFACES.TcInterval=2.0
  uci set olsrd.$INTERFACES.HnaValidityTime=125.0
  uci set olsrd.$INTERFACES.HelloValidityTime=125.0
  uci set olsrd.$INTERFACES.TcValidityTime=500.0
  uci set olsrd.$INTERFACES.Ip4Broadcast=255.255.255.255
  uci set olsrd.$INTERFACES.MidInterval=25.0
  uci set olsrd.$INTERFACES.HelloInterval=3.0
  uci set olsrd.$INTERFACES.HnaInterval=10.0


  # add txtinfo plugin - needed for collectd-mod-txtinfo
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.accept=0.0.0.0
  uci set olsrd.$PLUGIN.library=olsrd_txtinfo.so.0.1
  uci set olsrd.$PLUGIN.port=2006

  # add arprefresh plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.library=olsrd_arprefresh.so.0.1

  # add nameservice plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.library=olsrd_nameservice.so.0.3
  uci set olsrd.$PLUGIN.suffix=.olsr
  uci set olsrd.$PLUGIN.hosts_file=/tmp/hosts/olsr
  uci set olsrd.$PLUGIN.latlon_file=/var/run/latlon.js
  uci set olsrd.$PLUGIN.services_file=/var/etc/services.olsr

  # add jsoninfo plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.accept=0.0.0.0
  uci set olsrd.$PLUGIN.library=olsrd_jsoninfo.so.0.0
  uci set olsrd.$PLUGIN.ignore=0

  # add watchdog plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.library=olsrd_watchdog.so.0.1
  uci set olsrd.$PLUGIN.file=/var/run/olsrd.watchdog
  uci set olsrd.$PLUGIN.interval=30

  # add dyngw plain plugin - it is ipv4 only
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.library=olsrd_dyn_gw.so.0.5
  uci add_list olsrd.$PLUGIN.Ping=85.214.20.141     # dns.digitalcourage.de
  uci add_list olsrd.$PLUGIN.Ping=213.73.91.35      # dnscache.ccc.berlin.de
  uci add_list olsrd.$PLUGIN.Ping=194.150.168.168   # dns.as250.net
  uci set olsrd.$PLUGIN.ignore=0

  # add lan interface if meshLan is true
  local meshLan
  json_get_var meshLan meshLan
  if [ "$meshLan" == "1" ]; then
    INTERFACE="$(uci add olsrd Interface)"
    uci set olsrd.$INTERFACE.interface=lan
    uci set olsrd.$INTERFACE.Mode=ether
    uci set olsrd.$INTERFACE.ignore=0
  fi

  # add hna if distribute is true
  local distribute;
  json_get_var distribute distribute
  if [ "$distribute" == "1" ]; then
    local v4ClientSubnet
    json_get_var v4ClientSubnet v4ClientSubnet
    if [ -z "$v4ClientSubnet" ]; then
      log_olsrd "distribute true but v4ClientSubnet not found."
      exit 1
    fi
    eval "$(ipcalc.sh $v4ClientSubnet)"
    HNA="$(uci add olsrd Hna4)"
    uci set "olsrd.$HNA.netaddr=$NETWORK"
    uci set "olsrd.$HNA.netmask=$NETMASK"
  fi

  uci commit olsrd
}

setup_olsrd
