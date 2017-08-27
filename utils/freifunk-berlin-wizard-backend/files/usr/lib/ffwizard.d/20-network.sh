#!/bin/sh

. /usr/share/libubox/jshn.sh

log_network() {
  logger -s -t ffwizard_network "$@"
}

v4_get_subnet_first_ip() {
  eval "$(ipcalc.sh $1)"
  local OCTET_4="${NETWORK##*.}"
  local OCTET_1_3="${NETWORK%.*}"
  OCTET_4="$((OCTET_4 + 1))"
  echo "$OCTET_1_3.$OCTET_4/$PREFIX"
}

setup_rt_table() {
  local id="$1"
  local name="$2"
  tables="/etc/iproute2/rt_tables"
  test -d /etc/iproute2/ || mkdir -p /etc/iproute2/
  grep -q "$id $name" $tables || echo "$id $name" >> $tables
}

setup_policy_routing_rule() {
  local options="$@"
  RULE="$(uci add network rule)"
  for option in $options; do
    uci set network.$RULE.$option
  done

  RULE6="$(uci add network rule6)"
  for option in $options; do
    uci set network.$RULE6.$option
  done
}

setup_policy_routing() {
  ffInterfaces="$1"
  internetTunnel="$2"

  # remove all rules
  while uci -q delete "network.@rule[0]" > /dev/null; do :; done
  while uci -q delete "network.@rule6[0]" > /dev/null; do :; done

  # skip main table for freifunk traffic
  for interface in $ffInterfaces; do
    setup_policy_routing_rule priority=1000 in=$interface goto=1200
  done

  # main table (local interfaces)
  # TODO: see default route (below)
  # setup_policy_routing_rule priority=1100 lookup=main

  # freifunk main (local interfaces) and olsr tables
  setup_policy_routing_rule priority=1200 lookup=ff-main
  setup_policy_routing_rule priority=1210 lookup=ff-olsr2
  setup_policy_routing_rule priority=1211 lookup=ff-olsr
  setup_policy_routing_rule priority=1212 lookup=ff-mesh-tunnel

  # freifunk vpn default route
  for interface in $ffInterfaces; do
    setup_policy_routing_rule priority=1300 in=$interface lookup=ff-internet-tunnel
  done

  # skip default route (wan) for traffic
  if [ $internetTunnel == 1 ]; then
    for interface in $ffInterfaces; do
      setup_policy_routing_rule priority=1310 in=$interface goto=1500
    done
  fi

  # default route (wan)
  # note (André): this should be main-default but olsr looks in /proc/net/route /o\
  # TODO: fix olsr (or get rid of it)
  setup_policy_routing_rule priority=1400 lookup=main
  setup_policy_routing_rule priority=1400 lookup=main-default

  # freifunk default routes
  setup_policy_routing_rule priority=1500 lookup=ff-olsr2-default
  setup_policy_routing_rule priority=1500 lookup=ff-olsr-default

  # stop journey for freifunk traffic
  for interface in $ffInterfaces; do
    setup_policy_routing_rule priority=30000 in=$interface action=unreachable
  done
}

setup_network() {
  local cfg=$1
  json_init
  json_load "$CONFIG_JSON" || exit 1

  # add routing tables
  setup_rt_table 42 ff-main
  setup_rt_table 50 ff-olsr
  setup_rt_table 51 ff-olsr2
  setup_rt_table 52 ff-mesh-tunnel
  setup_rt_table 60 ff-internet-tunnel
  setup_rt_table 70 ff-olsr-default
  setup_rt_table 71 ff-olsr2-default
  setup_rt_table 80 main-default

  json_select ip

  local meshLan
  json_get_var meshLan meshLan

  # collect freifunk interfaces
  local ffInterfaces=""

  # get lan ifname
  local lanIfname="$(uci get ffwizard.@ffwizard[-1].lan_ifname)"

  # required for dhcp interface on wdr4300
  local lanMacaddr="$(uci -q get ffwizard.@ffwizard[-1].lan_macaddr)"

  # v6 prefix
  local v6Prefix
  uci -q delete network.loopback.ip6prefix
  json_get_var v6Prefix v6Prefix
  if [ -n "$v6Prefix" ]; then
    uci set "network.loopback.ip6prefix=$v6Prefix"
  fi

  # dns
  uci set network.loopback.dns="85.214.20.141 213.73.91.35 194.150.168.168 2001:4ce8::53 2001:910:800::12"

  # set table for wan
  # TODO: re-enable when olsr is fixed for non-default routing tables
  # uci set "network.wan.ip4table=main-default"
  # uci set "network.wan.ip6table=main-default"

  # lan interface (used for mesh or disabled if meshLan is true)
  uci -q delete network.lan
  uci -q delete network.lanbat

  if [ "$meshLan" == "1" ]; then
    ffInterfaces="${ffInterfaces} lan"

    uci set "network.lan=interface"
    uci set "network.lan.proto=static"
    uci set "network.lan.ifname=$lanIfname"
    uci set "network.lan.macaddr=$lanMacaddr"
    uci set "network.lan.ip6assign=64"
    uci set "network.lan.mtu=1532"
    uci set "network.lan.ip4table=ff-main"
    uci set "network.lan.ip6table=ff-main"

    json_select v4
    local v4Lan
    json_get_var v4Lan lan
    if [ -z "$v4Lan" ]; then
      log_network "meshLan is true but v4.lan is missing"
      exit 1
    fi
    eval "$(ipcalc.sh $v4Lan)"
    uci set "network.lan.ipaddr=$IP/32"
    json_select ..

    uci set "network.lanbat=interface"
    uci set "network.lanbat.proto=batadv"
    uci set "network.lanbat.ifname=@lan"
    uci set "network.lanbat.mesh=bat0"
    uci set "network.lanbat.mtu=1532"
    uci set "network.lanbat.ip4table=ff-main"
    uci set "network.lanbat.ip6table=ff-main"
  fi

  # dhcp interface (bridge with lanIfname if meshLan is false)
  ffInterfaces="${ffInterfaces} dhcp"

  uci -q delete network.dhcp
  uci set "network.dhcp=interface"
  uci set "network.dhcp.type=bridge"
  uci set "network.dhcp.ip4table=ff-main"
  uci set "network.dhcp.ip6table=ff-main"

  local dhcpIfnames="bat0"
  if [ "$meshLan" != "1" ]; then
    dhcpIfnames="$dhcpIfnames $lanIfname"
    uci set "network.dhcp.macaddr=$lanMacaddr"
  fi
  uci set "network.dhcp.ifname=$dhcpIfnames"

  # see https://github.com/freifunk-berlin/firmware/issues/297
  uci set "network.dhcp.igmp_snooping=0"

  local distribute;
  json_get_var distribute distribute
  if [ "$distribute" == "1" ]; then
    local v4ClientSubnet
    if ! json_get_var v4ClientSubnet v4ClientSubnet; then
      log_network "v4ClientSubnet missing."
      exit 1
    fi
    local v4ClientSubnetFirst=$(v4_get_subnet_first_ip $v4ClientSubnet)
    uci set "network.dhcp.proto=static"
    uci set "network.dhcp.ip6assign=64"
    uci set "network.dhcp.ipaddr=$v4ClientSubnetFirst"
  else
    uci set "network.dhcp.proto=dhcp"
  fi

  local idx

  # remove wireless interfaces
  idx=0
  while uci -q delete "network.wireless${idx}" > /dev/null; do
    idx=$((idx+1))
  done
  idx=0
  while uci -q delete "network.wireless${idx}bat" > /dev/null; do
    idx=$((idx+1))
  done

  json_select v4
  # add wireless interfaces
  idx=0
  while uci -q get "wireless.radio${idx}" > /dev/null; do
    ffInterfaces="${ffInterfaces} wireless${idx}"

    # add olsr mesh interface
    uci set "network.wireless${idx}=interface"
    uci set "network.wireless${idx}.proto=static"
    uci set "network.wireless${idx}.ip4table=ff-main"
    uci set "network.wireless${idx}.ip6table=ff-main"
    uci set "network.wireless${idx}.ip6assign=64"
    local v4Addr
    json_get_var v4Addr "radio${idx}"
    if [ -z "$v4Addr" ]; then
      log_network "no v4 ip found for radio${idx}"
      exit 1
    fi
    uci set "network.wireless${idx}.ipaddr=$v4Addr/32"

    # add batman mesh interface
    uci set "network.wireless${idx}bat=interface"
    uci set "network.wireless${idx}bat.proto=batadv"
    uci set "network.wireless${idx}bat.ifname=@wireless${idx}"
    uci set "network.wireless${idx}bat.mesh=bat0"
    uci set "network.wireless${idx}bat.ip4table=ff-main"
    uci set "network.wireless${idx}bat.ip6table=ff-main"

    idx=$((idx+1))
  done
  json_select ..

  # internet tunnel enabled?
  local internetTunnelConfig=$(echo $CONFIG_JSON | jsonfilter -e '@.internet.internetTunnel')
  local internetTunnel=0
  if [ ! -z "$internetTunnelConfig" ]; then
    internetTunnel=1

    uci set "network.internet_tunnel=interface"
    uci set "network.internet_tunnel.ifname=internet_tunnel"
    uci set "network.internet_tunnel.proto=none"
  fi

  setup_policy_routing "${ffInterfaces}" $internetTunnel

  uci commit network
}

setup_network
