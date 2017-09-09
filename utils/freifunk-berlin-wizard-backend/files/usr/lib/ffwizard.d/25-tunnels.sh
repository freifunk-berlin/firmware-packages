#!/bin/sh

. /usr/share/libubox/jshn.sh

log_tunnels() {
  logger -s -t ffwizard_tunnels "$@"
}

get_openvpn_option() {
  local configFilename=$1
  local option=$2

  # get matching line
  local match=$(grep -m 1 "^${option} " $configFilename)

  # strip option
  match="${match#$option }"

  # strip comment
  echo "${match%%#*}"
}

remove_openvpn_option() {
  local configFilename=$1
  local option=$2

  # remove line in config
  sed -i -e "/^${option}\( *\| .*\)\$/d" $configFilename
}

replace_openvpn_option() {
  local configFilename=$1
  local option=$2
  local value=$3

  remove_openvpn_option "$configFilename" "$option"

  # append new option
  echo "${option} $value" >> $configFilename
}

setup_openvpn() {
  local name=$1
  local tunnelConfig=$2

  mkdir -p /etc/openvpn
  rm -f /etc/openvpn/${name}.*

  # get files object
  local files=$(echo $tunnelConfig | jsonfilter -e '@.files')

  # save config
  local configFilename="/etc/openvpn/${name}.config"
  echo $files | jsonfilter -e '@.config' | base64 -d > $configFilename

  # ideally we'd want to get all keys via jsonfilter but it doesn't seem to support it
  json_init
  json_load "$files" || exit 1
  local options
  json_get_keys options

  # process file options
  for option in $options; do
    # skip config file because we already processed it
    if [ "$option" == "config" ]; then
      continue
    fi
    local filename="/etc/openvpn/${name}.${option}"

    # save file
    echo $files | jsonfilter -e "@.${option}" | base64 -d > $filename

    replace_openvpn_option "$configFilename" "$option" "$filename"
  done

  # remove some options
  for option in log log-append route-nopull up; do
    remove_openvpn_option "$configFilename" "$option"
  done

  # detect dev-type from dev if not provided
  local devType=$(get_openvpn_option "$configFilename" dev-type)
  if [ -z "$devType" ]; then
    local dev=$(get_openvpn_option "$configFilename" dev)
    if [ -z "${dev##tun*}" ]; then
      devType="tun"
    else
      devType="tap"
    fi
    replace_openvpn_option "$configFilename" dev-type "$devType"
  fi

  # set dev name
  replace_openvpn_option "$configFilename" dev "${name}_tunnel"

  # set status file
  replace_openvpn_option "$configFilename" status "/var/run/openvpn.${name}.status"

  # set mark (for matching in policyrouting)
  replace_openvpn_option "$configFilename" mark 1

  # we have to handle routes ourselves because openvpn doesn't support other routing tables
  replace_openvpn_option "$configFilename" route-noexec ""
  replace_openvpn_option "$configFilename" route-up "\"/usr/lib/ffwizard-openvpn/up.sh ${name}\""
  replace_openvpn_option "$configFilename" script-security 2

  # create uci config
  uci set "openvpn.${name}=openvpn"
  uci set "openvpn.${name}.enabled=1"
  uci set "openvpn.${name}.config=${configFilename}"
}

setup_tunnel() {
  local name=$1
  local tunnelConfig=$2

  local type=$(echo $tunnelConfig | jsonfilter -e '@.type')
  case $type in
    openvpn)
      setup_openvpn "$name" "$tunnelConfig"
      ;;
    *)
      echo "tunnel type $type not recognized"
      exit 1
  esac
}

setup_tunnels() {
  # reset openvpn config
  uci import openvpn <<EOF
EOF

  # internet tunnel
  local internetTunnelConfig=$(echo $CONFIG_JSON | jsonfilter -e '@.internet.internetTunnel')
  if [ ! -z "$internetTunnelConfig" ]; then
    setup_tunnel "internet" "$internetTunnelConfig"
  fi

  # mesh tunnel
  local meshTunnelConfig=$(echo $CONFIG_JSON | jsonfilter -e '@.internet.meshTunnel')
  if [ ! -z "$meshTunnelConfig" ]; then
    setup_tunnel "mesh" "$meshTunnelConfig"
  fi

  uci commit openvpn
}

setup_tunnels
