#!/bin/bash
#
# Brandon Gant
# 2017.04.25
#
# Usage:  /opt/rrdtool/scripts/jvm_memory_graph.sh <hour|day|week|month|year> <tomcat|solr|8080>

#--------------------------------------------
# Variables
#--------------------------------------------

TimeSpan="$1"
JVM="$2"
HOSTNAME=`hostname --short`
RRDFILES="/opt/rrdtool/rrdfiles"
GRAPH_DIR="/opt/rrdtool/graphs"

#--------------------------------------------
# Nothing to change below this line
#--------------------------------------------

cd $RRDFILES

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
Graph="$GRAPH_DIR/${HOSTNAME}-${JVM}-$TimeSpan.png"

 rrdtool graph $Graph \
         --start $Start --height=200 --width=795 \
         --title="${HOSTNAME} JVM Memory" --font TITLE:12: \
         --vertical-label="Memory (GB)" --font UNIT:10: \
         --lower-limit=0 --units-exponent 0 \
         --color=BACK#B5B1B1 --color=CANVAS#DDDDDD --color=SHADEB#666666 \
         TEXTALIGN:left \
         COMMENT:\\s COMMENT:\\s COMMENT:\\t \
         \
         DEF:server_ram_total_shade=server_ram_total.rrd:Data:AVERAGE AREA:server_ram_total_shade#BBBBBB \
         DEF:jvm_heap_max_${JVM}_shade=jvm_heap_max_${JVM}.rrd:Data:AVERAGE AREA:jvm_heap_max_${JVM}_shade#888888 \
         \
         DEF:server_ram_used=server_ram_used.rrd:Data:AVERAGE AREA:server_ram_used#280099:"server\\t" \
         VDEF:server_ram_used_print=server_ram_used,LAST \
         GPRINT:server_ram_used_print:"%3.0lfGB Used" \
         \
         DEF:server_ram_total=server_ram_total.rrd:Data:AVERAGE LINE2:server_ram_total#280099 \
         VDEF:server_ram_total_print=server_ram_total,LAST \
         GPRINT:server_ram_total_print:"/ %3.0lfGB Max" \
         \
         COMMENT:\\s COMMENT:\\s COMMENT:\\t \
         \
         DEF:jvm_heap_used_${JVM}=jvm_heap_used_${JVM}.rrd:Data:AVERAGE AREA:jvm_heap_used_${JVM}#99CCFF:"${JVM} jvm\\t" \
         VDEF:jvm_heap_used_${JVM}_print=jvm_heap_used_${JVM},LAST \
         GPRINT:jvm_heap_used_${JVM}_print:"%3.0lfGB Used" \
         \
         DEF:jvm_heap_max_${JVM}=jvm_heap_max_${JVM}.rrd:Data:AVERAGE LINE2:jvm_heap_max_${JVM}#99CCFF \
         VDEF:jvm_heap_max_${JVM}_print=jvm_heap_max_${JVM},LAST \
         GPRINT:jvm_heap_max_${JVM}_print:"/ %3.0lfGB Max   " \
         \
         COMMENT:\\s COMMENT:\\s COMMENT:\\t \
         \
         DEF:jvm_gc_${JVM}=jvm_gc_${JVM}.rrd:Data:AVERAGE AREA:jvm_gc_${JVM}#8A0000:"Garbage Collection Events" \
         \
         COMMENT:\\s COMMENT:\\s \
         TEXTALIGN:right \
         COMMENT:"Last data entered at $Time"

# --y-grid 1:5
# --x-grid MINUTE:15:HOUR:1:HOUR:6:0:%R 
# --upper-limit=10 --rigid

rsync --archive --progress $GRAPH_DIR/*.png <Your_Web_Server>::html/

exit 0

