#!/bin/bash

PID=`ps -e -o pid -o args | grep -v grep | grep /var/run/elasticsearch | awk -F' ' '{print $1}'`
renice -n +5 "$PID"

