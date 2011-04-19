#!/bin/sh

#set -x
#ip="77.87.48.65"
#ip="www.heise.de"
ip="77.87.48.81"
setdefaultgw=wan
#setdefaultgw=gvpn

pingparam="-c 5 -w 10 "
dev=$(uci get l2gvpn.bbb.tundev)
table=$(uci get olsrd.@olsrd[0].RtTable | echo default)
set $(ip route show | grep default)
# defaultgw=$3
defaultdev=$5


if ! ( [ $dev ] && [ $table ] && [ $defaultdev ] ) ; then
  logger -p 1 -t l2gvpnwatchdog "exit0 dev: $dev table: $table defaultdev: $defaultdev"
  exit 1
fi

if [ $setdefaultgw == "gvpn" ] ; then
	if ! ping $pingparam -I $dev $ip >/dev/null ; then 
		ucimac=$(uci get l2gvpn.bbb.mac)
		oldid=$(echo $ucimac | cut -d ':' -f 3 | sed -e s"/^0//")
		if [ "98" = "$oldid" ] ; then
		  newid="00"
		else
		  newid=$(printf "%02d\n" $((oldid + 1)))
		fi
		logger -p 1 -t l2gvpnwatchdog "oldid $oldid newid $newid"
	        uci set l2gvpn.bbb.mac=$(echo $ucimac | sed -e "s/^\(^.*:.*:\).*\(:.*:.*:.*$\)/\1$newid\2/")
	        uci commit
		logger -p 1 -t l2gvpnwatchdog "olducimac: $ucimac newucimac: $(uci get l2gvpn.bbb.mac)"
	        /etc/init.d/l2gvpn stop
	        sleep 2
	        killall node 2>/dev/null
	        sleep 2
	        killall -9 node 2>/dev/null
	        sleep 2
		/etc/init.d/l2gvpn start
	        sleep 5
	        rm /var/state/firewall
	        /etc/init.d/firewall restart
        	if ! ping $pingparam -I $dev $ip >/dev/null ; then
			logger -p 1 -t l2gvpnwatchdog "set default route to $defaultdev for table $table"
                	ip route add default dev $defaultdev table $table >/dev/null 2>&1
			#TODO
			#uci set olsrd.cfg1ac80c.ignore=0
			#uci commit
			#/etc/init.d/olsrd restart
		else
			logger -p 1 -t l2gvpnwatchdog "del default route to $defaultgw for table $table if exist"
			ip route del default dev $defaultdev table $table >/dev/null 2>&1
        	fi
	else
		if ip route show table $table | grep "default dev $defaultdev" >/dev/null 2>&1 ; then
			logger -p 1 -t l2gvpnwatchdog "del default route to $defaultdev for table $table if exist"
	  		ip route del default dev $defaultdev table $table >/dev/null 2>&1
		fi
	fi
fi

if [ $setdefaultgw == "wan" ] ; then
	if [ "$table" != "notable" ] ; then
		if ip route show table $table | grep "default .* dev $defaultdev" >/dev/null 2>&1 ; then
			logger -p 1 -t l2gvpnwatchdog "default route to $defaultdev for table $table"
		else
                	logger -p 1 -t l2gvpnwatchdog "set default route to $defaultdev for table $table"
                	ip route add default dev $defaultdev table $table >/dev/null 2>&1
		fi
	fi
	set -x
	gvpnrestart=0
	rxbytes=$(grep gvpn /proc/net/dev | awk '{ print $2}')
	txbytes=$(grep gvpn /proc/net/dev | awk '{ print $10}')
	if [ -f /tmp/gvpn.state ] ; then
		. /tmp/gvpn.state
		if [ $rxbytesold -eq $rxbytes -o $txbytesold -eq $txbytes ] ; then
			gvpnrestart=1
			echo "no rx or tx bytes"
		fi
	fi
	if ! ping $pingparam -I $dev $ip >/dev/null ; then 
		gvpnrestart=1
		echo "ping failure"
	fi
	rxbytes=$(grep gvpn /proc/net/dev | awk '{ print $2}')
	txbytes=$(grep gvpn /proc/net/dev | awk '{ print $10}')
	echo "rxbytesold=$rxbytes" > /tmp/gvpn.state
	echo "txbytesold=$txbytes" >> /tmp/gvpn.state
	if [ $gvpnrestart -eq 1 ]  ; then 
		ucimac=$(uci get l2gvpn.bbb.mac)
		oldid=$(echo $ucimac | cut -d ':' -f 3 | sed -e s"/^0//")
		if [ "98" = "$oldid" ] ; then
		  newid="00"
		else
		  newid=$(printf "%02d\n" $((oldid + 1)))
		fi
		logger -p 1 -t l2gvpnwatchdog "oldid $oldid newid $newid"
	        uci set l2gvpn.bbb.mac=$(echo $ucimac | sed -e "s/^\(^.*:.*:\).*\(:.*:.*:.*$\)/\1$newid\2/")
	        uci commit
		logger -p 1 -t l2gvpnwatchdog "olducimac: $ucimac newucimac: $(uci get l2gvpn.bbb.mac)"
	        /etc/init.d/l2gvpn stop
	        sleep 2
	        killall node 2>/dev/null
	        sleep 2
	        killall -9 node 2>/dev/null
	        sleep 2
		/etc/init.d/l2gvpn start
			        sleep 5
	        rm /var/state/firewall
	        /etc/init.d/firewall restart
	fi
fi
