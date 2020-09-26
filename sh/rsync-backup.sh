#!/bin/sh
# Source: https://netfuture.ch/2013/08/simple-versioned-timemachine-like-backup-using-rsync/
#
# Usage: rsync-backup.sh <src> <dst> <label>
# Example 7-Day Rotation:   ./rsync-backup.sh ~/rke-rancher/ /nfs-backup/ `date +rke-rancher-%u`
# Example 52-Week Rotation: ./rsync-backup.sh ~/rke-rancher/ /nfs-backup/rke-rancher/ `date +Week-%U`
#
if [ "$#" -ne 3 ]; then
    echo "$0: Expected 3 arguments, received $#: $@" >&2
    exit 1
fi
if [ -d "$2/__prev/" ]; then
    rsync -a --checksum --delete --link-dest="$2/__prev/" "$1" "$2/$3"
else
    rsync -a                                   "$1" "$2/$3"
fi
rm -f "$2/__prev"
ln -s "$3" "$2/__prev"
