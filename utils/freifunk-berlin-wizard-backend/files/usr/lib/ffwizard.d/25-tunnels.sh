#!/bin/sh

. /usr/share/libubox/jshn.sh

log_tunnels() {
  logger -s -t ffwizard_tunnels "$@"
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

    # remove line in config
    sed -i -e "/^${option} /d" $configFilename

    # append new option
    echo "${option} $filename" >> $configFilename
  done
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
  # internet tunnel
  local internetTunnelConfig=$(echo $CONFIG_JSON | jsonfilter -e '@.internet.tunnel')
  if [ ! -z "$internetTunnelConfig" ]; then
    setup_tunnel "internet" "$internetTunnelConfig"
  fi

  # TODO: mesh tunnel
}

setup_tunnels
