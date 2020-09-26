#!/bin/ash

echo "Updating Package Database..."
opkg -V0 update
LIST=$(opkg -V1 list-upgradable | cut -f 1 -d ' ')

if [ -n $LIST ]
then
  echo "No packages to upgrade"
else
  echo $LIST | xargs opkg upgrade
fi
