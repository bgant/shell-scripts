#!/bin/bash
#
# capture SYN/ACK flagged packets
# tcp[13] is the byte location of TCP flags (URG,ACK,PSH,RST,SYN,FIN)
#
# mnemonic
#
# Unskilled 32
# Attackers 16
# Pester     8
# Real       4
# Security   2
# Folks      1

PORT=$1

# -l in tcpdump allows one live pipe
sudo tcpdump -i eth0 -l 'tcp[13] & 2 != 0 && tcp[13] & 16 != 0' and dst port $PORT and not dst net 192.168.0.128/25 | awk -F'.' '{printf("%s.%s.%s.%s.%s.%s.%s.%s.%s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9)}'
