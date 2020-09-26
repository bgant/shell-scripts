#!/bin/bash
#
# Brandon Gant
# 2016-08-31


MPRIME="/opt/rrdtool/scripts/mprime-quiet"
TIME="/usr/bin/time --format=%e"
SERVER=`hostname --short`

CORES=$((`nproc`-1))
for i in `seq 0 $CORES`
do
   RRDFILE="/opt/rrdtool/rrdfiles/${SERVER}_cpu${i}.rrd"
   if [ -e $RRDFILE ]
   then 
        RESPONSE=$( { $TIME taskset -c $i $MPRIME | tr -d '\r'; } 2>&1 )
        echo "CPU $i: $RESPONSE"
	/usr/bin/rrdtool update ${RRDFILE} N:${RESPONSE}
   else
	echo "Creating RRD File: $RRDFILE"
	/usr/bin/rrdtool create $RRDFILE DS:Data:GAUGE:600:U:U \
	RRA:AVERAGE:0.5:1:600 RRA:AVERAGE:0.5:6:700 RRA:AVERAGE:0.5:24:775 RRA:AVERAGE:0.5:288:1895 \
	RRA:MAX:0.5:1:600 RRA:MAX:0.5:6:700 RRA:MAX:0.5:24:775 RRA:MAX:0.5:288:1895 \
	RRA:MIN:0.5:1:600 RRA:MIN:0.5:6:700 RRA:MIN:0.5:24:775 RRA:MIN:0.5:288:1895
   fi
done

