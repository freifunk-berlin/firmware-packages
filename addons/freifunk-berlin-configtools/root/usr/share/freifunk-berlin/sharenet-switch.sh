#!/bin/sh
#
# Copyright (C) 2018 holger@freifunk-berlin
# taken from https://github.com/openwrt-mirror/openwrt/blob/95f36ebcd774a8e93ad2a1331f45d1a9da4fe8ff/target/linux/ar71xx/base-files/etc/uci-defaults/02_network#L83
#
# This script should set a wan-Port if u want to share ur internet-connection.
# It should run after wizard did the necessary settings (sharenet = yes)
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
board=$(ubus call system board | jsonfilter -e '$.board_name')

echo $board

case "$board" in
gl-ar150|\
glinet,gl-ar150)
	echo $board found
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
	;;
loco-m-xw)
	echo $board found
#	eth tauschen?
	;;
rb-wapg-5hact2hnd)
	echo $board found
#	eth tauschen?
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
