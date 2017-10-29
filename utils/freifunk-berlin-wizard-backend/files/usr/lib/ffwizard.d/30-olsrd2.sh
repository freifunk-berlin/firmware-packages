#!/bin/sh

log_olsrd2() {
  logger -s -t ffwizard_olsrd2 "$@"
}

setup_olsrd2() {
  /etc/init.d/olsrd2 enable

  # reset olsrd2 config
  uci import olsrd2 <<EOF
EOF

  # set olsrd2 defaults
  GLOBAL="$(uci add olsrd2 global)"
  uci set olsrd2.$GLOBAL.failfast=no
  uci set olsrd2.$GLOBAL.pidfile=/var/run/olsrd2.pid
  uci set olsrd2.$GLOBAL.lockfile=/var/lock/olsrd2

  LOG="$(uci add olsrd2 log)"
  uci set olsrd2.$LOG.syslog=true
  uci set olsrd2.$LOG.stderr=true

  TELNET="$(uci add olsrd2 telnet)"
  uci set olsrd2.$TELNET.port=2010

  DOMAIN="$(uci add olsrd2 domain)"
  uci set olsrd2.$DOMAIN.table=51

  INTERFACE="$(uci add olsrd2 interface)"
  uci set olsrd2.$INTERFACE.ifname=loopback
  uci set olsrd2.$INTERFACE.ignore=0
  uci add_list olsrd2.$INTERFACE.bindto=-0.0.0.0/0
  uci add_list olsrd2.$INTERFACE.bindto=-::1
  uci add_list olsrd2.$INTERFACE.bindto=default_accept

  # add lan interface if meshLan is true
  local meshLan=$(echo $CONFIG_JSON | jsonfilter -e '@.ip.meshLan')
  if [ "$meshLan" == "true" ]; then
    INTERFACE="$(uci add olsrd2 interface)"
    uci set olsrd2.$INTERFACE.ifname=lan
    uci set olsrd2.$INTERFACE.ignore=0
    # TODO: set actual bitrate?
    uci set olsrd2.$INTERFACE.rx_bitrate=1G
    uci set olsrd2.$INTERFACE.tx_bitrate=1G
    uci add_list olsrd2.$INTERFACE.bindto=-0.0.0.0/0
    uci add_list olsrd2.$INTERFACE.bindto=-::1
    uci add_list olsrd2.$INTERFACE.bindto=default_accept
  fi

  # add wireless interfaces
  local idx=0
  while uci -q get "wireless.radio${idx}" > /dev/null; do
    INTERFACE="$(uci add olsrd2 interface)"
    uci set olsrd2.$INTERFACE.ifname="wireless${idx}"
    uci set olsrd2.$INTERFACE.ignore=0
    uci add_list olsrd2.$INTERFACE.bindto=-0.0.0.0/0
    uci add_list olsrd2.$INTERFACE.bindto=-::1
    uci add_list olsrd2.$INTERFACE.bindto=default_accept
    idx=$((idx+1))
  done

  # TODO: uplink (wan/internet_tunnel) and mesh_tunnel

  uci commit olsrd2
}

setup_olsrd2
