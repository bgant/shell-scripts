#!/bin/bash
#
# This script is called from 
# Start --> Settings --> Session and Startup --> Application Autostart --> OpenVPN Startup
#
# Tested on GalliumOS Chromebook but should work with any Ubuntu Desktop
#

# Wait for nm-applet to start
until pids=$(pidof nm-applet)
do   
    sleep 1
done
# nm-applet has now started.

# Wait for wireless connection
until up=$(ip link show wlp1s0 | grep 'state UP')
do
    sleep 1
done
# Wireless should be running now

# Start OpenVPN
until vpn=$(ip link show tun0 | grep 'UP')
do
    nmcli con up is-us-01.protonvpn.com.udp
    #nmcli con up is-us-01.protonvpn.com.tcp
    #nmcli con up ch-us-01.protonvpn.com.udp
    #nmcli con up ch-us-01.protonvpn.com.tcp
    sleep 3
done
# OpenVPN should be running now
