#!/bin/sh

. /lib/functions.sh

PLUGIN_SET=false

is_dnsmasq() {
  config_get script $1 cmdline
  [ $script = '/etc/collectd/dnsmasq.sh' ] && PLUGIN_SET=true
}

config_load luci_statistics
config_foreach is_dnsmasq collectd_exec_input

[ $PLUGIN_SET  = true ] && exit 0

cat >>/etc/config/luci_statistics <<EOF
config collectd_exec_input
        option cmdline '/etc/collectd/dnsmasq.sh'
        option cmduser 'nobody'
        option cmdgroup 'nogroup'

EOF
