#!/bin/sh

. /usr/share/libubox/jshn.sh

log_batman_adv() {
  logger -s -t ffwizard_batman_adv "$@"
}

setup_batman_adv() {
  local cfg=$1
  json_init
  json_load "$CONFIG_JSON" || exit 1

  json_select ip

  uci -q delete batman-adv.bat0
  uci set batman-adv.bat0=mesh

  uci set batman-adv.bat0.bridge_loop_avoidance=1

  local distribute;
  json_get_var distribute distribute
  if [ "$distribute" == "1" ]; then
    uci set batman-adv.bat0.gw_mode=server
    # TODO
    # uci set batman-adv.bat0.gw_bandwidth=25000kbit/5000kbit
  else
    uci set batman-adv.bat0.gw_mode=client
  fi

  uci commit batman-adv
}

setup_batman_adv
