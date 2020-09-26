#!/bin/ash
#
# Upgrade via CLI: https://openwrt.org/docs/guide-user/installation/sysupgrade.cli
# Asus RT-N56U: https://openwrt.org/toh/asus/rt-n56u
# Asus RT-N56U: https://downloads.openwrt.org/releases/19.07.2/targets/ramips/rt3883/
#
# Preserve files during upgrade:
#  vi /etc/sysupgrade.conf
#    /root
#    /etc/rc.local
#

##########################################
# Clear out any old files                 
##########################################
rm /tmp/releases 2> /dev/null
rm /tmp/version.buildinfo 2> /dev/null
rm /tmp/*.bin 2> /dev/null      
rm /tmp/sha256sums* 2> /dev/null


##########################################                                                                                          
# What is the Latest Release?                                                                                                      
##########################################                                                                                          
cd /tmp                                                                                                                             
wget -q "https://downloads.openwrt.org/releases/"                                                                                     
RELEASE=`cat releases | awk -F'href="' '{print $2}' | awk -F'/' '{print $1}' | grep ^[0-9] | grep -v rc | sort | tail -n1`
echo "Current Release: $RELEASE"


##########################################
# Variables for specific OpenWRT device
##########################################
#RELEASE="19.07.2"
TARGET1="ramips"
TARGET2="rt3883"
DEVICE="rt-n56u"
VERSION="https://downloads.openwrt.org/releases/$RELEASE/targets/$TARGET1/$TARGET2/version.buildinfo"
FIRMWARE="https://downloads.openwrt.org/releases/$RELEASE/targets/$TARGET1/$TARGET2/openwrt-$RELEASE-$TARGET1-$TARGET2-$DEVICE-squashfs-sysupgrade.bin"
SHA256SUMS="https://downloads.openwrt.org/releases/$RELEASE/targets/$TARGET1/$TARGET2/sha256sums"
SIGNATURE="https://downloads.openwrt.org/releases/$RELEASE/targets/$TARGET1/$TARGET2/sha256sums.sig"


##########################################
# New version of Firmware available?
##########################################
cd /tmp
wget -q $VERSION
cmp /etc/openwrt_version /tmp/version.buildinfo  # No diff command / Using cmp "compare" command
if [ $? == 0 ]  # File contents match
then
  echo "New Firmware: FALSE"
  exit 0
else
  echo "New Firmware: TRUE"
fi


##########################################
# OpenWRT Developer Signature Verification
##########################################
# Source: https://openwrt.org/docs/guide-user/security/release_signatures
# https://git.openwrt.org/?p=keyring.git;a=tree;f=usign
# https://git.openwrt.org/?p=keyring.git;a=blob_plain;f=usign/f94b9dd6febac963  <-- Copied to /root/usign/
wget -q $SHA256SUMS
wget -q $SIGNATURE
usign -V -P /root/usign/ -q -x /tmp/sha256sums.sig -m /tmp/sha256sums
if [ $? == 0 ]
then
  echo "sha256sums Signature Verification: SUCCESS"
else
  echo "sha256sums Signature Verification: FAILED"
  exit 0
fi


##########################################
# Firmware Checksum and Upgrade
##########################################
wget -q $FIRMWARE
grep $DEVICE /tmp/sha256sums > /tmp/sha256sums.$DEVICE
sha256sum -c /tmp/sha256sums.$DEVICE
if [ $? == 0 ]
then
  echo "Firmware Checksum: SUCCESS"
  echo "Upgrading Firmware..."
  sysupgrade -F -v /tmp/*.bin
else
  echo "Firmware Checksum: FAILED"
fi

