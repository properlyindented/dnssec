#!/bin/sh

DEV=/root/araneus-random-device

cd
umask 077
test -e $DEV && rm $DEV
mknod araneus-random-device p

isrunning()
{
	BIN=$1
	PIDFILE=/var/run/`basename $BIN`
	NUM=
	if [ -r $PIDFILE ]
	then
		childpid=`cat $PIDFILE`
		if `echo $childpid | grep -qE '^[0-9]+$'`
		then
			if `kill -0 $childpid`
			then
				return 1
			fi
		fi
	fi
	return 0
}

while true
do
	BIN=robert/bin/araneus-random-number
	if isrunning $BIN
	then
		$BIN -b > $DEV &
		childpid=$!
		echo $childpid > /var/run/`basename $BIN`
		wait -n $childpid
	fi
	sleep 30
done &

sleep 1
while true
do
	BIN=rngd
	if isrunning $BIN
		then
		$BIN 	--rng-quality=high				\
			--rng-device=$DEV 				\
			--fill-watermark=100				\
			--rng-timeout=0					\
			--foreground >/dev/null
	fi
	sleep 31
done &
