#!/bin/sh
#
# Copyright (C) 2018 holger@freifunk-berlin
# taken from https://github.com/openwrt-mirror/openwrt/blob/95f36ebcd774a8e93ad2a1331f45d1a9da4fe8ff/target/linux/ar71xx/base-files/etc/uci-defaults/02_network#L83
#
# This script should set a wan-Port if u want to share ur internet-connection.
# It should run after wizard did the necessary settings (sharenet = yes)

. /lib/functions.sh

# what shall I do?
AUTOCOMMIT="no"

while getopts "c" option; do
        case "$option" in
                c)
                        AUTOCOMMIT="yes"
                        ;;
                *)
                        echo "Invalid argument '-$OPTARG'."
                        exit 1
                        ;;    
        esac              
done        
shift $((OPTIND - 1))

echo "usage $0 -c [commit]"

# redefines the assignment of the VLANs of the switch ports
# e.g. eth0.1: from switchport 4 to port 5 (TPLink CPE)
swap_port_switch() {
  echo "todo: implement swap_port_switch"
  exit 200
}

# swaps the assignment of pyhsical ports of the device
# e.g. eth0 <--> eth1 (NSM)
swap_port_physical() {
  local port1=$1
  local port2=$2
  local port1_interfaces=""
  local port2_interfaces=""

  interfaces_of_dev() {
    local device=$1

    lua <<EOF
uci=require("uci")
local ifaces = ""
x=uci.cursor()
x:foreach("network", "interface", function(s)
-- io.stderr:write(" testing interface:" .. tostring(s[".name"] .. "\n"))
 if (tostring(s["ifname"]) == "${device}") then
--  io.stderr:write("  fount ${device} on interface " .. tostring(s[".name"] .. "\n"))
  ifaces = ifaces .. " " .. s[".name"]
 end
end)
print(ifaces)
EOF
  }

  port1_interfaces=$(interfaces_of_dev ${port1})
  port2_interfaces=$(interfaces_of_dev ${port2})
echo $port1 is interface of $port1_interfaces
echo $port2 is interface of $port2_interfaces
  for iface in ${port1_interfaces}; do
    uciif=$(uci get network.${iface}.ifname)
    uci set network.${iface}.ifname="$(echo $uciif | sed -e s/${port1}/${port2}/g)"
  done
  for iface in ${port2_interfaces}; do
    uciif=$(uci get network.${iface}.ifname)
    uci set network.${iface}.ifname="$(echo $uciif | sed -e s/${port2}/${port1}/g)"
  done
}

# replaces the interface assigned to the pyhsical ports of the device
# this is used on single-LANport board w/o switch (NSM loco)
swap_port_interface() {
  echo "todo: implement swap_port_interface"
  exit 200
}

# a fresh installed single-port device has no WAN-interface generated by
# OpenWrt initial setup. So we need to create one ourself.
create_wan_interface() {
  if [ "interface" = $(uci -q get network.wan) ]; then
    echo "WAN-interface already exisiting"
    return
  fi
  echo "todo: implement create_wan_interface"
  
}

sharenet=$(uci -q get ffwizard.settings.sharenet)
[ $? -ne 0 ] && {
  echo 'sharenet value unknown'
  exit 1
}

if [ "${sharenet}" = "0" ]; then
    echo 'dont share my internet - set Freifunk-LAN to PoE-port'
    POEPORT='dhcp'
elif [ "${sharenet}" = "1" ]; then
    echo 'share my internet - set WAN to PoE-port'
    POEPORT='wan'
else
    echo 'sharenet has invalid value'
    exit 2
fi

. /lib/functions/uci-defaults.sh 	# routines that set switch etc

# which board are we running on, what will we change?
board=$(board_name)

echo $board

case "$board" in
gl-ar150|\
glinet,gl-ar150)
	echo $board found
	swap_port_physical
	;;
cpe210|\
cpe510|\
tplink,cpe210-v1|\
tplink,cpe510-v1)
	echo $board found
#	should this be more sophisticated?
	uci set network.@switch_vlan[0].ports='0t 4'
	uci set network.@switch_vlan[1].ports='0t 5'
	;;
nanostation-m|\
nanostation-m-xw|\
ubnt,nanostation-m|\
ubnt,nanostation-m-xw)
	echo $board found
#	eth tauschen?
	swap_port_physical eth0 eth1
	;;
loco-m-xw|\
ubnt,nanostation-loco-m)
	echo $board found
	create_wan_interface
#	eth tauschen?
	swap_port_interface
	;;
rb-wapg-5hact2hnd)
	echo $board found
	create_wan_interface
#	eth tauschen?
	swap_port_switch
	;;
*)
	echo "This board ($board) is not PoE powered"
	;;
esac

# shall I commit changes? Yes, when called by hand.
if [ ${AUTOCOMMIT} == "yes" ];  then
	echo 'uci commit network';
	uci commit network;
	/etc/init.d/network restart
	else 
	echo 'uci dont commit network'
	
fi

exit 0
