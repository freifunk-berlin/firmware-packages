#!/usr/bin/env sh

source ./lib/functions/semver.sh

#OLD_VERSION=$(uci get system.version.version)
OLD_VERSION='0.0.0'
VERSION='0.1.0' # $(cat /etc/openwrt_version)

function update_openvpn_remote_config() {
  # use dns instead of ips for vpn servers (introduced with 0.1.0)
  uci delete openvpn.ffvpn.remote
  uci add_list openvpn.ffvpn.remote='vpn03.berlin.freifunk.net 1194 udp'
  uci add_list openvpn.ffvpn.remote='vpn03-backup.berlin.freifunk.net 1194 udp'
}

function update_openvpn_lease_config() {
  # set lease time to 5 minutes (introduced with 0.1.0)
  uci set dhcp.dhcp.leasetime='5m'
}

function update_wireless_ht20_config() {
  # set htmode to ht20 (introduced with 0.1.0)
  uci set wireless.radio0.htmode='ht20'
  if uci get wireless.radio1; then
    uci set wireless.radio1.htmode='ht20'
  fi
}

echo "Migrating from ${OLD_VERSION} to ${VERSION}."

if semverLT ${OLD_VERSION} "0.1.0"; then

  update_openvpn_remote_config
  update_dhcp_lease_config
  update_wireless_ht20_config

fi

# set version old to current version after update
# uci set system.version.version=${VERSION}

echo "Migration done."
