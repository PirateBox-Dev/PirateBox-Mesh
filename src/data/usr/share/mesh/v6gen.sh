#!/bin/sh
#
#  Generate a dynamic IPv6 adress with fixed prefix.
#   Matthias Strubel 2012   matthias.strubel@aod-rpg.de
#
#   Based on:
#
#	@(#) generate-rfc4193-addr.sh (ULA)  (c) Sep 2004 - Jun 2011	Holger Zuleger 
#
#	do what the name suggest 
#
#	firstpart = 64-Bit NTP time
#	secondpart = EUI-64 Identifier or 48 Bit MAC-Adress
#	sha1sum ($firstpart | $secondpart )
#	use least significant 40 Bits of sha1sum
#	build global prefix (locally assigned == FD00::/8)
#
#	
PATH=/usr/local/bin:/bin:/usr/bin:/usr/sbin:/sbin

debug=0
USE_NTPQ=1
NTPSERVER=pool.ntp.org

#(M4)
LC_ALL=C
export LC_ALL

IN_PREFIX="fd00"

test -n "$1" && IN_PREFIX=$1 


#(M3)
if test $USE_NTPQ -eq 1
then
	if time=`ntpq -c rv | grep clock=`
	then
		test $debug -eq 1 && echo "$time"
		firstpart=`echo $time | sed  -e "s/clock=//" -e "s/ .*//" -e "s/\.//"`
	else
		echo "no local ntpd running" 1>&2
		exit 1
	fi
else
	#(M1)
	#(M2)
	firstpart=`ntpdate -d -q $NTPSERVER 2>/dev/null | sed "/transmit timestamp/q" |
		sed  -n "/transmit time/s/^transmit timestamp: *\([^ ]*\) .*/\1/p" |
		tr -d "."`
fi

secondpart=`ifconfig eth0 |
	grep "inet6 addr: fe80" |
	sed  -n "s|^.*::\([^/]*\)/.*|\1|p" |
	tr -d ":"`

#(M1)
if test -z "$firstpart" -o -z "$secondpart"
then
	echo "$0: installation error: check if ntpdate and ifconfig is in search path"
	exit 1
fi

test $debug -eq 1 && echo "Firstpart: $firstpart"
test $debug -eq 1 && echo "Secondpart: $secondpart"
test $debug -eq 1 && echo "123456789o123456789o123456789o123456789o123456789o123456789o"
test $debug -eq 1 && echo ${firstpart}${secondpart} | sha1sum

#(M5)
globalid=`echo ${firstpart}${secondpart} | tr -d "\012" | sha1sum | cut -c25-40`
test $debug -eq 1 && echo $globalid


FIXED=`echo ${globalid} |  sed "s|\(....\)\(....\)\(....\)\(....\)|\1:\2:\3:\4|"`

test  $debug -eq 1 && echo $FIXED

echo $IN_PREFIX::$FIXED

