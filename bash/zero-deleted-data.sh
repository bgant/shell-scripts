#!/bin/bash

# This file will zero out any deleted data that is taking up space in the volume.
# This is needed on Pure Storage to keep the disk space and snapshots at a reasonable level.

DIR="$1"
LIMIT="99"

if [ -z "$1" ]
then
   echo "Specify Directory to write zero files... Exiting"
   exit 0
fi

echo "Creating 1GB $DIR/zero.file.small file..."
dd if=/dev/zero of=$DIR/zero.file.small bs=1G count=1
echo .
echo "Creating 10G $DIR/zero.file.medium file..."
dd if=/dev/zero of=$DIR/zero.file.medium bs=1G count=10
echo .
echo "Writing zeros to the rest of free space in $DIR/zero.file.large until $LIMIT% limit is reached..."
dd if=/dev/zero of=$DIR/zero.file.large &

DF="0"
while [ "$DF" -lt "$LIMIT" ]
do
  sleep 10
  DF=`df --local $DIR | grep -v Use | awk -F' ' '{print $5}' | awk -F'%' '{print $1}'`
  echo "$DF% Used < $LIMIT% Limit"
done

kill `pgrep -x dd`

echo .
rm -v $DIR/zero.file.small
rm -v $DIR/zero.file.medium
rm -v $DIR/zero.file.large
echo .

