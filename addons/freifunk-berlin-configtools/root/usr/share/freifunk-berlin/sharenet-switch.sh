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

# should this script run?
if [ "$(uci get ffwizard.settings.sharenet 2> /dev/null)" == "0" ]; then
    echo 'dont share my internet' && exit 0
else
	if [ "$(uci get ffwizard.settings.sharenet 2> /dev/null)" == "1" ]; then
    		echo 'share my internet'
	else
		echo 'sharenet value unknown' && exit 0
	fi
fi

. /lib/functions/uci-defaults.sh 	# routines that set switch etc

# which board are we running on, what will we change?
board=$(ubus call system board | jsonfilter -e '$.board_name')

echo $board

case "$board" in
gl-ar150)
	echo $board found
	;;
cpe210|\
cpe510)
	echo $board found
#	should this be more sophisticated?
	uci set network.@switch_vlan[0].ports='0t 4'
	uci set network.@switch_vlan[1].ports='0t 5'
	;;
nanostation-m|\
nanostation-m-xw)
	echo $board found
#	eth tauschen?
	;;
loco-m-xw)
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
