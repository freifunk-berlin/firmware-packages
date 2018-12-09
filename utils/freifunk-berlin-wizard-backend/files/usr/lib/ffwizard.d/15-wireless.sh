#!/bin/sh

. /usr/share/libubox/jshn.sh

log_wireless() {
  logger -s -t ffwizard_wireless "$@"
}

setup_wireless() {
  local cfg=$1

  # reset wifi config
  rm -f /etc/config/wireless
  wifi config
  iw reg set DE

  # remove wifi-ifaces
  local idx=0
  while uci -q delete wireless.@wifi-iface[-1] > /dev/null; do
    idx=$((idx+1))
  done

  # loop over radios
  idx=0
  while uci -q get "wireless.radio${idx}" > /dev/null; do
    log_wireless "setting up radio${idx}"

    local device="radio$idx"

    uci set wireless.$device.disabled=0
    uci set wireless.$device.country=DE
    # TODO: read from config
    uci set wireless.$device.distance=1000

    # get valid hwmods
    local hw_a=0
    local hw_b=0
    local hw_g=0
    local hw_n=0
    local info_data=$(ubus call iwinfo info '{ "device": "radio'$idx'" }' 2>/dev/null)
    if [ -z "$info_data" ]; then
      log_wireless "No iwinfo data for radio$idx"
      return 1
    fi
    json_load "$info_data"
    json_select hwmodes
    json_get_values hw_res
    if [ -z "$hw_res" ]; then
      log_wireless "No iwinfo hwmodes for radio$idx"
      return 1
    fi
    for i in $hw_res ; do
      case $i in
        a) hw_a=1 ;;
        b) hw_b=1 ;;
        g) hw_g=1 ;;
        n) hw_n=1 ;;
      esac
    done
    [ "$hw_a" == 1 ] && log_wireless "HWmode a"
    [ "$hw_b" == 1 ] && log_wireless "HWmode b"
    [ "$hw_g" == 1 ] && log_wireless "HWmode g"
    [ "$hw_n" == 1 ] && log_wireless "HWmode n"

    # get valid channel list
    local channels
    local channel
    local chan_data=$(ubus call iwinfo freqlist '{ "device": "radio'$idx'" }' 2>/dev/null)
    if [ -z "$chan_data" ]; then
      log_wireless "No iwinfo freqlist for radio$idx"
      return 1
    fi
    json_load "$chan_data"
    json_select results
    json_get_keys chan_res
    for i in $chan_res ; do
      json_select "$i"
      # check which channels are available
      json_get_var restricted restricted
      if [ "$restricted" == 0 ] ; then
        json_get_var channel channel
        channels="$channels $channel"
      fi
      json_select ..
    done

    # get channel
    local channel
    for i in $channels ; do
      if [ "$i" == "36" ] ; then
        channel="36"
        break
      fi
      if [ "$i" == "13" ] ; then
        channel="13"
      fi
    done
    log_wireless "Channel $channel"
    uci set "wireless.$device.channel=$channel"

    if [ $hw_n == 1 ]; then
      # avoid adhoc interfaces that do not come up
      # see https://dev.openwrt.org/ticket/18268
      uci set wireless.$device.noscan=1
      [ $hw_a == 1 ] && uci set wireless.$device.doth=0

      # get ht mode
      local htmode
      [ $channel -gt 165 ] && htmode="HT40+"
      # Channel 165 HT40-
      [ $channel -le 165 ] && htmode="HT40-"
      # Channel 153,157,161 HT40+
      [ $channel -le 161 ] && htmode="HT40+"
      # Channel 104 - 140 HT40-
      [ $channel -le 140 ] && htmode="HT40-"
      # Channel 100 HT40+
      [ $channel -le 100 ] && htmode="HT40+"
      # Channel 40 - 64 HT40-
      [ $channel -le 64 ] && htmode="HT40-"
      # Channel 36 HT40+
      [ $channel -le 36 ] && htmode="HT40+"
      # Channel 1 - 14 HT20
      [ $channel -le 14 ] && htmode="HT20"
      if [ -n "$htmode" ]; then
        uci set "wireless.$device.htmode=$htmode"
      fi
    fi

    # adhoc bssid
    local bssid
    if [ $channel -gt 0 -a $channel -lt 10 ] ; then
      bssid=$channel"2:CA:FF:EE:BA:BE"
    elif [ $channel -eq 10 ] ; then
      bssid="02:CA:FF:EE:BA:BE"
    elif [ $channel -gt 10 -a $channel -lt 15 ] ; then
      bssid=$(printf "%X" "$channel")"2:CA:FF:EE:BA:BE"
    elif [ $channel -gt 35 -a $channel -lt 100 ] ; then
      bssid="02:"$channel":CA:FF:EE:EE"
    elif [ $channel -gt 99 -a $channel -lt 199 ] ; then
      bssid="12:"$(printf "%02d" "$(expr $channel - 100)")":CA:FF:EE:EE"
    fi

    local iface
    # add mesh interface
    iface="$(uci add wireless wifi-iface)"
    uci set wireless.$iface.device="radio${idx}"
    uci set wireless.$iface.network="wireless${idx}"
    uci set wireless.$iface.mode=adhoc
    uci set wireless.$iface.ifname="wlan${idx}-mesh"
    uci set wireless.$iface.ssid="intern-ch${channel}.freifunk.net"
    uci set wireless.$iface.bssid="${bssid}"
    uci set wireless.$iface.mcast_rate=6000

    # add dhcp interface
    iface="$(uci add wireless wifi-iface)"
    uci set wireless.$iface.device="radio${idx}"
    uci set wireless.$iface.network=dhcp
    uci set wireless.$iface.mode=ap
    uci set wireless.$iface.ifname="wlan${idx}-dhcp"
    uci set wireless.$iface.ssid="berlin.freifunk.net"
    uci set wireless.$iface.mcast_rate=6000
    uci set wireless.$iface.disassoc_low_ack=0

    idx=$((idx+1))
  done

  uci commit wireless
}

setup_wireless
