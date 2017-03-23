#!/bin/sh

. /lib/functions.sh

ADDON_SECTIONS=''

find_dnsmasq_addon() {
  config_get script $1 cmdline
  [ $script = '/etc/collectd/dnsmasq.sh' ] && ADDON_SECTIONS="${ADDON_SECTIONS} $1"
}

# remove old addon-config(s)
config_load luci_statistics
config_foreach find_dnsmasq_addon collectd_exec_input
for section in ${ADDON_SECTIONS}; do 
  uci delete luci_statistics.$section
done

# add updated addon-config and enable exec-plugin
uci -m import luci_statistics <<EOF
config statistics 'collectd_exec'
        option enable '1'

config collectd_exec_input
        option cmdline '/etc/collectd/dnsmasq.sh'
        option cmduser 'nobody'
        option cmdgroup 'nogroup'
EOF

uci commit luci_statistics
