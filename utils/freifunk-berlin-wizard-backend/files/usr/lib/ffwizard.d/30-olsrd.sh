#!/bin/sh

. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh

log_olsrd() {
  logger -s -t ffwizard_olsrd "$@"
}

setup_olsrd() {
  local cfg=$1
  json_init
  json_load "$CONFIG_JSON" || exit 1

  json_select ip

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
  # uci set olsrd.$OLSRD.SmartGateway=yes
  # uci set olsrd.$OLSRD.SmartGatewayThreshold=50
  uci set olsrd.$OLSRD.Pollrate=0.025
  uci set olsrd.$OLSRD.RtTable=50
  uci set olsrd.$OLSRD.RtTableDefault=70
  # TODO: re-enable when policy routing is back in a sane form
  # uci set olsrd.$OLSRD.RtTableTunnel=70
  # uci set olsrd.$OLSRD.RtTableTunnelPriority=100000
  # uci set olsrd.$OLSRD.RtTableDefaultOlsrPriority=20000

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
  uci set olsrd.$PLUGIN.library=olsrd_txtinfo
  uci set olsrd.$PLUGIN.port=2006
  uci set olsrd.$PLUGIN.httpheaders=true

  # add arprefresh plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.library=olsrd_arprefresh

  # add nameservice plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.library=olsrd_nameservice
  uci set olsrd.$PLUGIN.suffix=.olsr
  uci set olsrd.$PLUGIN.hosts_file=/tmp/hosts/olsr
  uci set olsrd.$PLUGIN.latlon_file=/var/run/latlon.js
  uci set olsrd.$PLUGIN.services_file=/var/etc/services.olsr

  # add jsoninfo plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.accept=0.0.0.0
  uci set olsrd.$PLUGIN.library=olsrd_jsoninfo
  uci set olsrd.$PLUGIN.ignore=0
  uci set olsrd.$PLUGIN.httpheaders=true

  # add watchdog plugin
  PLUGIN="$(uci add olsrd LoadPlugin)"
  uci set olsrd.$PLUGIN.library=olsrd_watchdog
  uci set olsrd.$PLUGIN.file=/var/run/olsrd.watchdog
  uci set olsrd.$PLUGIN.interval=30

  # add dyngw plain plugin if internet shared (note: the plugin is ipv4 only)
  local shareInternet=$(echo $CONFIG_JSON | jsonfilter -e '@.internet.share')
  if [ "$shareInternet" == "true" ]; then
    # use internet_tun (with tunnel) or wan device name (without tunnel)
    local tunnel=$(echo $CONFIG_JSON | jsonfilter -e '@.internet.tunnel')
    local uplinkDev="internet_tun"
    if [ -z "$tunnel" ]; then
      network_get_physdev uplinkDev wan
    fi

    PLUGIN="$(uci add olsrd LoadPlugin)"
    uci set olsrd.$PLUGIN.library=olsrd_dyn_gw
    uci set olsrd.$PLUGIN.PingCmd="ping -c 1 -q -I $uplinkDev %s"
    uci set olsrd.$PLUGIN.PingInterval=30
    uci add_list olsrd.$PLUGIN.Ping=85.214.20.141     # dns.digitalcourage.de
    uci add_list olsrd.$PLUGIN.Ping=213.73.91.35      # dnscache.ccc.berlin.de
    uci add_list olsrd.$PLUGIN.Ping=194.150.168.168   # dns.as250.net
    uci set olsrd.$PLUGIN.ignore=0
  fi

  # add lan interface if meshLan is true
  local meshLan
  json_get_var meshLan meshLan
  if [ "$meshLan" == "1" ]; then
    INTERFACE="$(uci add olsrd Interface)"
    uci set olsrd.$INTERFACE.interface=lan
    uci set olsrd.$INTERFACE.Mode=ether
    uci set olsrd.$INTERFACE.ignore=0
  fi

  # add wireless interfaces
  local idx=0
  while uci -q get "wireless.radio${idx}" > /dev/null; do
    INTERFACE="$(uci add olsrd Interface)"
    uci set olsrd.$INTERFACE.interface="wireless${idx}"
    uci set olsrd.$INTERFACE.ignore=0
    idx=$((idx+1))
  done

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
