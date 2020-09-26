#!/bin/bash

# Usage:  /opt/rrdtool/scripts/mprime_graph.sh hour

SERVER=`hostname --short`
#FREQUENCY=`lscpu | grep "CPU MHz" | awk -F' ' '{print $3}' | awk -F'.' '{print $1}'`
FREQUENCY=`lscpu | grep "Model name" | awk -F'@' '{print $2}' | cut --complement -c1`
cd /opt/rrdtool/rrdfiles/

echo "waiting a few seconds..."
sleep 10

TimeSpan="$1"

case $TimeSpan in
"day")
Start="-129600";;
"week")
Start="-864000";;
"month")
Start="-5184000";;
"year")
Start="-47433600";;
"hour")
Start="-7200";;
*)
Start="-129600"
TimeSpan="day";;
esac

Time=`/bin/date +%a" "%b" "%d" "%H"\:"%M"\:"%S`
Graph="/opt/rrdtool/graphs/${SERVER}_mprime-$TimeSpan.png"

 rrdtool graph $Graph                                                             \
         --start $Start --height=200 --width=795                                  \
         --title="${SERVER} Response Time" --font TITLE:12:     \
         --vertical-label="seconds" --font UNIT:10:                               \
         --lower-limit=1 --upper-limit=2 --units-exponent 0             \
         --color=BACK#B5B1B1 --color=CANVAS#DDDDDD --color=SHADEB#666666          \
         TEXTALIGN:left \
         COMMENT:\\s COMMENT:\\s COMMENT:\\t \
         COMMENT:"Server CPU speed ${FREQUENCY}\: "  \
         DEF:cpu0=${SERVER}_cpu0.rrd:Data:AVERAGE LINE2:cpu0#FF0000:"CPU0"  \
         DEF:cpu1=${SERVER}_cpu1.rrd:Data:AVERAGE LINE2:cpu1#00FF00:"CPU1"  \
         DEF:cpu2=${SERVER}_cpu2.rrd:Data:AVERAGE LINE2:cpu2#0000FF:"CPU2"  \
         DEF:cpu3=${SERVER}_cpu3.rrd:Data:AVERAGE LINE2:cpu3#7D51A8:"CPU3"  \
         COMMENT:\\s COMMENT:\\s COMMENT:\\s COMMENT:\\t \
         COMMENT:"(an idle 2.90GHz CPU should take 1.0 seconds to complete the mprime task)"\\s \
         COMMENT:\\s COMMENT:\\s  \
         TEXTALIGN:right \
         COMMENT:"Last data entered at $Time"

# --y-grid 1:5
# --x-grid MINUTE:15:HOUR:1:HOUR:6:0:%R 
# --upper-limit=10 --rigid

#rsync --archive /opt/rrdtool/graphs/${SERVER}_mprime-$TimeSpan.png <Your_Website>::html/

