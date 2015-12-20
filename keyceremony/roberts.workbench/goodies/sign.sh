#!/bin/bash

PATH=/bin:/usr/bin

home=`dirname $0`
for p in /opt/bind*
do
    for p2 in bin sbin
    do
        if [ -d $p/$p2 ]
        then
            PATH=${p}/${p2}:${PATH}
        fi
    done
done
cd $home
now=`date +%s`
musthup=0
##

sign()
{
    z=$1
    mkdir zones.plain zones.signed 2>/dev/null
    if [ -e zones.plain/$z ]
    then
        in=zones.plain/$z
    else
        in=$z
    fi
    if [ -d zones.signed ]
    then
        out=zones.signed/$z
    else
        out=$z.signed
    fi
    sign=0
    if [ -e $in -a ! -e $out ]
    then
        sign=1
    elif [ $in -nt $out ]
    then
        sign=1
    fi
    if [ -e $out ]
    then
        if [ $(( `date -r $out +%s` + 82000 )) -lt $now ]
        then
            sign=1
        fi
    fi
    if [ $sign = 0 ]
    then
        return
    fi
    echo '###' Signing $z
    dnssec-signzone -3 - -N unixtime -K keys -d keys -S -o $z -f $out -a -T 3600 -x $in
    musthup=1
}

haskey()
{
    z=$1
    for key in keys/K*$1.+*
    do
        if [ -e $key ]
        then
            return 0
        fi
    done
    return 1
}

for unsigned in zones.plain/*
do
    zone=`basename $unsigned`
    if haskey $zone
    then
        sign $zone
    fi
done
if [ $musthup = 1 ]
then
    ./rndc2 reload
fi
