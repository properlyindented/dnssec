#!/bin/sh

for zones in dk nic.dk
do
	dnssec-keygen
	dnssec-signzone -e +160d -o dnssec.dk -T 86400 -Atxz -k Kdnssec.dk.+007+47676.key dnssec.dk.dnskeys 
	named-compilezone -i none -o - dnssec.dk dnssec.dk.dnskeys.signed | expand | grep -E ' IN *(RRSIG *DNSKEY|DNSKEY) '

done
