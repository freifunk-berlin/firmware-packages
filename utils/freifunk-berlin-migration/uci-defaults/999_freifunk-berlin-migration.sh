#!/usr/bin/env sh

source /lib/functions.sh
source /lib/functions/semver.sh
source /etc/openwrt_release

# possible cases: 
# 1) firstboot with kathleen --> uci system.version not defined
# 2) upgrade from kathleen --> uci system.version defined
# 3) upgrade from non kathleen / legacy --> no uci system.version

OLD_VERSION=$(uci -q get system.@system[0].version)
# remove "special-version" e.g. "-alpha+3a7d"; only work on "basic" semver-strings
VERSION=${DISTRIB_RELEASE%%-*}

log() {
  logger -s -t freifunk-berlin-migration $@
  echo >>/root/migrate.log $@
}

if [ "Freifunk Berlin" = "${DISTRIB_ID}" ]; then
  log "Migration is running on a Freifunk Berlin system"
else
  log "no Freifunk Berlin system detected ..."
  exit 0
fi

# when upgrading from a pre-kathleen installation, there sould be
# at least on "very old file" in /etc/config ...
#
FOUND_OLD_FILE=false
# create helper to compare file ctime (1. Sep. 2014)
touch -d "201409010000" /tmp/timestamp
for testfile in /etc/config/*; do
  if [ "${testfile}" -ot /tmp/timestamp ]; then
    FOUND_OLD_FILE=true
    echo "guessing pre-kathleen firmware as of ${testfile}"
  fi
done
rm -f /tmp/timestamp

if [ -n "${OLD_VERSION}" ]; then
  # case 2)
  log "normal migration within Release ..."
elif [ ${FOUND_OLD_FILE} = true ]; then
  # case 3)
  log "migrating from legacy Freifunk Berlin system ..."
  OLD_VERSION='0.0.0'
else
  # case 1)
  log "fresh install - no migration"
  # add system.version with the new version
  log "Setting new system version to ${VERSION}; no migration needed."
  uci set system.@system[0].version=${VERSION}
  uci commit
  exit 0
fi

update_openvpn_remote_config() {
  # use dns instead of ips for vpn servers (introduced with 0.1.0)
  log "Setting openvpn.ffvpn.remote to vpn03.berlin.freifunk.net"
  uci delete openvpn.ffvpn.remote
  uci add_list openvpn.ffvpn.remote='vpn03.berlin.freifunk.net 1194 udp'
  uci add_list openvpn.ffvpn.remote='vpn03-backup.berlin.freifunk.net 1194 udp'
}

update_dhcp_lease_config() {
  # set lease time to 5 minutes (introduced with 0.1.0)
  local current_leasetime=$(uci get dhcp.dhcp.leasetime)
  if [ "x${current_leasetime}" = "x" ]; then
    log "Setting dhcp lease time to 5m"
    uci set dhcp.dhcp.leasetime='5m'
  fi
}

update_wireless_ht20_config() {
  # set htmode to ht20 (introduced with 0.1.0)
  log "Setting htmode to HT20 for radio0"
  uci set wireless.radio0.htmode='HT20'
  local radio1_present=$(uci get wireless.radio1.htmode)
  # set htmode if radio1 is present
  if [ "x${radio1_present}" != x ]; then
    log "Setting htmode to HT20 for radio1."
    uci set wireless.radio1.htmode='HT20'
  fi
}

update_luci_statistics_config() {
  # if users disabled stats with the wizard some settings need be corrected
  # so they can enable stats later
  log "remove luci_statistics.rrdtool.enable"
  log "remove luci_statistics.collectd.enable"
  uci delete luci_statistics.rrdtool.enable
  uci delete luci_statistics.collectd.enable

  # enable luci_statistics service
  log "enable luci_statistics service"
  /etc/init.d/luci_statistics enable
}

update_collectd_memory_leak_hotfix() {
  # Remove old hotfixes for collectd RAM issues on 32MB routers
  # see https://github.com/freifunk-berlin/firmware/issues/217
  CRONTAB="/etc/crontabs/root"
  test -f $CRONTAB || touch $CRONTAB
  sed -i '/luci_statistics$/d' $CRONTAB
  sed -i '/luci_statistics restart$/d' $CRONTAB
  /etc/init.d/cron restart

  if [ "$(cat /proc/meminfo |grep MemTotal:|awk {'print $2'})" -lt "65536" ]; then
    uci set luci_statistics.collectd_ping.enable=0
    uci set luci_statistics.collectd_rrdtool.enable=0
  fi
}

update_olsr_smart_gateway_threshold() {
  # set SmartGatewayThreshold if not set
  local threshold=$(uci get olsrd.@olsrd[0].SmartGatewayThreshold)
  if [ "x${threshold}" = x ]; then
    log "Setting SmartGatewayThreshold to 50."
    uci set olsrd.@olsrd[0].SmartGatewayThreshold='50'
  fi
}

fix_olsrd_txtinfo_port() {
  uci set $(uci show olsrd|grep olsrd_txtinfo|cut -d '=' -f 1|sed 's/library/port/')=2006
  uci set $(uci show olsrd6|grep olsrd_txtinfo|cut -d '=' -f 1|sed 's/library/port/')=2006
}

add_openvpn_mssfix() {
  uci set openvpn.ffvpn.mssfix=1300
}

openvpn_ffvpn_hotplug() {
  uci set openvpn.ffvpn.up="/lib/freifunk/ffvpn-up.sh"
  uci set openvpn.ffvpn.nobind=0
  /etc/init.d/openvpn disable
  for entry in `uci show firewall|grep Reject-VPN-over-ff|cut -d '=' -f 1`; do
    uci delete ${entry%.name}
  done
  uci delete freifunk-watchdog
  crontab -l | grep -v "/usr/sbin/ffwatchd" | crontab -
}

update_collectd_ping() {
 uci set luci_statistics.collectd_ping.Interval=10
 uci set luci_statistics.collectd_ping.Hosts=ping.berlin.freifunk.net
}

fix_qos_interface() {
  for rule in `uci show qos|grep qos.wan`; do
    uci set ${rule/wan/ffvpn}
  done
  uci delete qos.wan
}

sgw_rules_to_fw3() {
  uci set firewall.zone_freifunk.device=tnl_+
  sed -i '/iptables -I FORWARD -o tnl_+ -j ACCEPT$/d' /etc/firewall.user
}

remove_dhcp_interface_lan() {
  uci -q delete dhcp.lan
  uci commit dhcp
}

change_olsrd_dygw_ping() {
  change_olsrd_dygw_ping_handle_config() {
    local config=$1
    local library=''
    config_get library $config library
    if [ $library == 'olsrd_dyn_gw.so.0.5' ]; then
      uci delete olsrd.$config.Ping
      uci add_list olsrd.$config.Ping=85.214.20.141     # dns.digitalcourage.de
      uci add_list olsrd.$config.Ping=213.73.91.35      # dnscache.ccc.berlin.de
      uci add_list olsrd.$config.Ping=194.150.168.168   # dns.as250.net
      uci commit
      return 1
    fi
  }
  reset_cb
  config_load olsrd
  config_foreach change_olsrd_dygw_ping_handle_config LoadPlugin
}

fix_dhcp_start_limit() {
  # only set start and limit if we have a dhcp section
  if (uci -q show dhcp.dhcp); then
    # only alter start and limit if not set by the user
    if ! (uci -q get dhcp.dhcp.start || uci -q get dhcp.dhcp.limit); then
      local netmask
      local prefix
      # get network-length
      if netmask="$(uci -q get network.dhcp.netmask)"; then
        # use ipcalc.sh to and get prefix-length only
        prefix="$(ipcalc.sh 0.0.0.0 ${netmask} |grep PREFIX|awk -F "=" '{print $2}')"
        # compute limit (2^(32-prefix)-3) with arithmetic evaluation
        limit=$((2**(32-${prefix})-3))
        uci set dhcp.dhcp.start=2
        uci set dhcp.dhcp.limit=${limit}
        log "set new dhcp.limit and dhcp.start on interface dhcp"
      else
        log "interface dhcp has no netmask assigned. not fixing dhcp.limit"
      fi
    else
      log "interface dhcp has start and limit defined. not changing it"
    fi
  else
    log "interface dhcp has no dhcp-config at all"
  fi
}

delete_system_latlon() {
  log "removing obsolete uci-setting system.system.latlon"
  uci -q delete system.@system[0].latlon
  uci commit system
}

fix_olsrd6_watchdog_file() {
  log "fix olsrd6 watchdog file"
  uci set $(uci show olsrd6|grep "/var/run/olsrd.watchdog"|cut -d '=' -f 1)=/var/run/olsrd6.watchdog
}

migrate () {
  log "Migrating from ${OLD_VERSION} to ${VERSION}."

  if semverLT ${OLD_VERSION} "0.1.0"; then
    update_openvpn_remote_config
    update_dhcp_lease_config
    update_wireless_ht20_config
    update_luci_statistics_config
    update_olsr_smart_gateway_threshold
  fi

  if semverLT ${OLD_VERSION} "0.1.1"; then
    update_collectd_memory_leak_hotfix
    fix_olsrd_txtinfo_port
  fi

  if semverLT ${OLD_VERSION} "0.1.2"; then
    add_openvpn_mssfix
  fi

  if semverLT ${OLD_VERSION} "0.2.0"; then
    update_collectd_ping
    fix_qos_interface
    remove_dhcp_interface_lan
    openvpn_ffvpn_hotplug
    sgw_rules_to_fw3
    change_olsrd_dygw_ping
    fix_dhcp_start_limit
    delete_system_latlon
    fix_olsrd6_watchdog_file
  fi

  # overwrite version with the new version
  log "Setting new system version to ${VERSION}."
  uci set system.@system[0].version=${VERSION}

  uci commit

  log "Migration done."

  # delete any overlay config files duplicated from romfs by sysupgrade - saves JFFS2 space
  cd /overlay/upper/etc/config/ && for i in *; do [ -f "$i" ] && if cmp -s "$i" "/rom/etc/config/$i"; then rm -f "$i"; fi; done;
}

migrate
