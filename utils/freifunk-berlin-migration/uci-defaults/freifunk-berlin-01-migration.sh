#!/usr/bin/env sh

source /lib/functions.sh
source /lib/functions/semver.sh
source /etc/openwrt_release
source /lib/functions/guard.sh

# possible cases: 
# 1) firstboot with kathleen --> uci system.version not defined
# 2) upgrade from kathleen --> uci system.version defined
# 3) upgrade from non kathleen / legacy --> no uci system.version

OLD_VERSION=$(uci -q get system.@system[0].version)
# remove "special-version" e.g. "-alpha+3a7d"; only work on "basic" semver-strings
VERSION=${DISTRIB_RELEASE%%-*}

log() {
  logger -s -t freifunk-berlin-migration "$@"
  echo >>/root/migrate.log "$@"
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
}

update_berlin_owm_api() {
  if [ "$(uci get freifunk.community.name)" = "berlin" ]; then
    log "updating Berlin OWM API URL"
    uci set freifunk.community.owm_api="http://util.berlin.freifunk.net"
  fi
}

fix_olsrd6_watchdog_file() {
  log "fix olsrd6 watchdog file"
  uci set $(uci show olsrd6|grep "/var/run/olsrd.watchdog"|cut -d '=' -f 1)=/var/run/olsrd6.watchdog
}

vpn03_udp4() {
  log "set VPN03 to UDPv4 only"
  uci delete openvpn.ffvpn.remote
  uci add_list openvpn.ffvpn.remote='vpn03.berlin.freifunk.net 1194'
  uci add_list openvpn.ffvpn.remote='vpn03-backup.berlin.freifunk.net 1194'
  uci set openvpn.ffvpn.proto=udp4
}

set_ipversion_olsrd6() {
  uci set olsrd6.@olsrd[0].IpVersion=6
}

r1_0_0_vpn03_splitconfig() {
  log "changing guard-entry for VPN03 from openvpn to vpn03-openvpn (config-split for VPN03)"
  guard_rename openvpn vpn03_openvpn # to guard the current settings of package "freifunk-berlin-vpn03-files"
}

r1_0_0_no_wan_restart() {
  crontab -l | grep -v "^0 6 \* \* \* ifup wan$" | crontab -
}

r1_0_0_firewallzone_uplink() {
  log "adding firewall-zone for VPN / Uplink"
  uci set firewall.zone_ffuplink=zone
  uci set firewall.zone_ffuplink.name=ffuplink
  uci set firewall.zone_ffuplink.input=REJECT
  uci set firewall.zone_ffuplink.forward=ACCEPT
  uci set firewall.zone_ffuplink.output=ACCEPT
  uci set firewall.zone_ffuplink.network=ffuplink
  # remove ffvpn from zone freifunk
  ffzone_new=$(uci get firewall.zone_freifunk.network|sed -e "s/ ffvpn//g")
  log " zone freifunk has now interfaces: ${ffzone_new}"
  uci set firewall.zone_freifunk.network="${ffzone_new}"
  log " setting up forwarding for ffuplink"
  uci set firewall.fwd_ff_ffuplink=forwarding
  uci set firewall.fwd_ff_ffuplink.src=freifunk
  uci set firewall.fwd_ff_ffuplink.dest=ffuplink
}

r1_0_0_change_to_ffuplink() {
  change_olsrd_dygw_ping_iface() {
    local config=$1
    local lib=''
    config_get lib $config library
    if [ -z "${lib##olsrd_dyn_gw.so*}" ]; then
      uci set olsrd.$config.PingCmd='ping -c 1 -q -I ffuplink %s'
      return 1
    fi
  }
  remove_routingpolicy() {
    local config=$1
    case "$config" in
      olsr_*_ffvpn_ipv4*) 
        log "  network.$config"
        uci delete network.$config
        ;;
      *) ;;
    esac
  }

  log "changing interface ffvpn to ffuplink"
  log " setting wan as bridge"
  uci set network.wan.type=bridge
  log " renaming interface ffvpn"
  uci rename network.ffvpn=ffuplink
  uci set network.ffuplink.ifname=ffuplink
  log " updating VPN03-config"
  uci rename openvpn.ffvpn=ffuplink
  uci set openvpn.ffuplink.dev=ffuplink
  uci set openvpn.ffuplink.status="/var/log/openvpn-status-ffuplink.log"
  uci set openvpn.ffuplink.key="/etc/openvpn/ffuplink.key"
  uci set openvpn.ffuplink.cert="/etc/openvpn/ffuplink.crt"
  log " renaming VPN03 certificate files"
  mv /etc/openvpn/freifunk_client.crt /etc/openvpn/ffuplink.crt
  mv /etc/openvpn/freifunk_client.key /etc/openvpn/ffuplink.key
  log " updating statistics, qos, olsr to use ffuplink"
  # replace ffvpn by ffuplink
  ffuplink_new=$(uci get luci_statistics.collectd_interface.Interfaces|sed -e "s/ffvpn/ffuplink/g")
  uci set luci_statistics.collectd_interface.Interfaces="${ffuplink_new}"
  uci rename qos.ffvpn=ffuplink
  reset_cb
  config_load olsrd
  config_foreach change_olsrd_dygw_ping_iface LoadPlugin
  log " removing deprecated IP-rules"
  reset_cb
  config_load network
  config_foreach remove_routingpolicy rule
}

r1_0_0_update_preliminary_glinet_names() {
  case `uci get system.led_wlan.sysfs` in
    "gl_ar150:wlan")
      log "correcting system.led_wlan.sysfs for GLinet AR150"
      uci set system.led_wlan.sysfs="gl-ar150:wlan"
      ;;
    "gl_ar300:wlan")
      log "correcting system.led_wlan.sysfs for GLinet AR300"
      uci set system.led_wlan.sysfs="gl-ar300:wlan"
      ;;
    "domino:blue:wlan")
      log "correcting system.led_wlan.sysfs for GLinet Domino"
      uci set system.led_wlan.sysfs="gl-domino:blue:wlan"
      ;;
  esac
}

r1_0_0_upstream() {
  log "applying upstream changes / sync with upstream"
  grep -q "^kernel.core_pattern=" /etc/sysctl.conf || echo >>/etc/sysctl.conf "kernel.core_pattern=/tmp/%e.%t.%p.%s.core"
  sed -i '/^net.ipv4.tcp_ecn=0/d' /etc/sysctl.conf
  grep -q "^128" /etc/iproute2/rt_tables || echo >>/etc/iproute2/rt_tables "128	prelocal"
  cp /rom/etc/inittab /etc/inittab
  cp /rom/etc/profile /etc/profile
  cp /rom/etc/hosts /etc/hosts
  log " checking for user dnsmasq"
  group_exists "dnsmasq" || group_add "dnsmasq" "453"
  user_exists "dnsmasq" || user_add "dnsmasq" "453" "453"
}

r1_0_0_set_uplinktype() {
  log "storing used uplink-type"
  log " migrating from Kathleen-release, assuming VPN03 as uplink-preset"
  echo "" | uci import ffberlin-uplink
  uci set ffberlin-uplink.preset=settings
  uci set ffberlin-uplink.preset.current="vpn03_openvpn"
}

r1_0_1_set_uplinktype() {
  uci >/dev/null -q get ffberlin-uplink.preset && return 0

  log "storing used uplink-type for Hedy"
  uci set ffberlin-uplink.preset=settings
  uci set ffberlin-uplink.preset.current="unknown"
  if [ "$(uci -q get network.ffuplink_dev.type)" = "veth" ]; then
    uci set ffberlin-uplink.preset.current="no-tunnel"
  else
    case "$(uci -q get openvpn.ffuplink.remote)" in
      \'vpn03.berlin.freifunk.net*)
        uci set ffberlin-uplink.preset.current="vpn03_openvpn"
        ;;
      \'tunnel-gw.berlin.freifunk.net*)
        uci set ffberlin-uplink.preset.current="tunnelberlin_openvpn"
        ;;
    esac
    fi
  log " type set to $(uci get ffberlin-uplink.preset.current)"
}

r1_1_0_change_olsrd_lib_num() {
  log "remove suffix from olsrd plugins"
  change_olsrd_lib_num_handle_config() {
    local config=$1
    local v6=$2
    local library=''
    local librarywo=''
    config_get library $config library
    librarywo=$(echo ${library%%.*})
    uci set olsrd$v6.$config.library=$librarywo
    log " changed olsrd$v6 $librarywo"
  }
  reset_cb
  config_load olsrd
  config_foreach change_olsrd_lib_num_handle_config LoadPlugin
  config_load olsrd6
  config_foreach change_olsrd_lib_num_handle_config LoadPlugin 6

}

r1_1_0_notunnel_ffuplink() {
  if [ "$(uci -q get ffberlin-uplink.preset.current)" == "no-tunnel" ]; then
    log "update the ffuplink_dev to have a static macaddr if not already set"
    local macaddr=$(uci -q get network.ffuplink_dev.macaddr)
    if [ $? -eq 1 ]; then
      # Create a static random macaddr for ffuplink device
      # start with fe for ffuplink devices
      # See the website https://www.itwissen.info/MAC-Adresse-MAC-address.html
      macaddr="fe"
      for byte in 2 3 4 5 6; do
        macaddr=$macaddr`dd if=/dev/urandom bs=1 count=1 2> /dev/null | hexdump -e '1/1 ":%02x"'`
      done
      uci set network.ffuplink_dev.macaddr=$macaddr
    fi
  fi
}

r1_1_0_notunnel_ffuplink_ipXtable() {
  if [ "$(uci -q get ffberlin-uplink.preset.current)" == "no-tunnel" ]; then
    log "update the ffuplink no-tunnel settings to use options ip4table and ip6table"
    uci set network.ffuplink.ip4table="ffuplink"
    uci set network.ffuplink.ip6table="ffuplink"
  fi
}

r1_1_0_olsrd_dygw_ping() {
  olsrd_dygw_ping() {
    local config=$1
    local lib=''
    config_get lib $config library
    local libname=${lib%%.*}
    if [ $lib == "olsrd_dyn_gw" ]; then
      uci del_list olsrd.$config.Ping=213.73.91.35   # dnscache.ccc.berlin.de
      uci add_list olsrd.$config.Ping=80.67.169.40   # www.fdn.fr/actions/dns
      uci del_list olsrd.$config.Ping=85.214.20.141  # old digitalcourage
      uci add_list olsrd.$config.Ping=46.182.19.48   # new digitalcourage
      return 1
    fi
  }
  reset_cb
  config_load olsrd
  config_foreach olsrd_dygw_ping LoadPlugin
}

r1_0_2_update_dns_entry() {
  log "updating DNS-servers for interface dhcp from profile"
  uci set network.dhcp.dns="$(uci get "profile_$(uci get freifunk.community.name).interface.dns")"
}

r1_0_2_add_olsrd_garbage_collection() {
  crontab -l | grep "rm -f /tmp/olsrd\*core"
  if [ $? == 1 ]; then
    log "adding garbage collection of core files from /tmp"
    echo "23 4 * * *	rm -f /tmp/olsrd*core" >> /etc/crontabs/root
    /etc/init.d/cron restart
  fi
}

r1_1_0_remove_olsrd_garbage_collection() {
  log "removing garbage collection of core files from /tmp"
  crontab -l | grep -v "rm -f /tmp/olsrd\*core" | crontab -
  /etc/init.d/cron restart
}

r1_1_0_update_dns_entry() {
  network_interface_delete_dns() {
    local config=${1}
    uci -q del network.${config}.dns
  }
  reset_cb
  config_load network
  config_foreach network_interface_delete_dns Interface
  uci set network.loopback.dns="$(uci get "profile_$(uci get freifunk.community.name).interface.dns")"
}

r1_1_0_update_uplink_notunnel_name() {
  log "update name of uplink-preset notunnel"
  local result=$(uci -q get ffberlin-uplink.preset.current)
  [[ $? -eq 0 ]] && [[ $result == "no-tunnel" ]] && uci set ffberlin-uplink.preset.current=notunnel
  result=$(uci -q get ffberlin-uplink.preset.previous)
  [[ $? -eq 0 ]] && [[ $result == "no-tunnel" ]] && uci set ffberlin-uplink.preset.previous=notunnel
  log "update name of uplink-preset notunnel done"
}

r1_1_0_firewall_remove_advanced() {
  firewall_remove_advanced() {
    uci -q delete firewall.$1
  }
  config_load firewall
  config_foreach firewall_remove_advanced advanced
}

migrate () {
  log "Migrating from ${OLD_VERSION} to ${VERSION}."

  # check for every migration task folder
  for scriptdir in /usr/share/freifunk-berlin-migration/*; do
    # only do mirgations for releases higher then the one we are come from
    if semverLT ${OLD_VERSION} "${scriptdir}"; then
      # run each script / task of the release-mirgation
      for script in /usr/share/freifunk-berlin-migration/${scriptdir}; do
        /bin/sh /usr/share/freifunk-berlin-migration/${scriptdir}/${script}
      done
    fi
  done

  # overwrite version with the new version
  log "Setting new system version to ${VERSION}."
  uci set system.@system[0].version=${VERSION}

  uci commit

  log "Migration done."
}

migrate
