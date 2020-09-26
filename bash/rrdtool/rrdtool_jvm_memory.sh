#!/bin/bash
#
# Brandon Gant 
# 2016-08-17
#
# This script monitors JVM RAM
#
#--------------------------------------------
# Variables to change on each server
#--------------------------------------------


JVM_IDENTIFIER="$2"
JSTAT="/usr/bin/jstat"
JCMD="/usr/bin/jcmd"
GCLOG="/opt/rrdtool/scripts/last_jvm_gc_${2}.log"

#--------------------------------------------
# /etc/crontab entries:
#--------------------------------------------

# #------ JVM Memory Usage Graph for Solr
# */5 * * * *   root nice /opt/rrdtool/scripts/rrd_update.sh jvm_heap_used.rrd "/opt/rrdtool/scripts/jvm_memory.sh jvm_heap_used" > /dev/null 2>&1
# */5 * * * *   root nice /opt/rrdtool/scripts/rrd_update.sh jvm_heap_max.rrd "/opt/rrdtool/scripts/jvm_memory.sh jvm_heap_max" > /dev/null 2>&1
# */5 * * * *   root nice /opt/rrdtool/scripts/rrd_update.sh jvm_gc.rrd "/opt/rrdtool/scripts/jvm_memory.sh jvm_gc" > /dev/null 2>&1
# */5 * * * *  user1 nice /opt/rrdtool/scripts/rrd_update.sh server_ram_total.rrd "/opt/rrdtool/scripts/jvm_memory.sh server_ram_total" > /dev/null 2>&1
# */5 * * * *  user1 nice /opt/rrdtool/scripts/rrd_update.sh server_ram_used.rrd "/opt/rrdtool/scripts/jvm_memory.sh server_ram_used" > /dev/null 2>&1
# */5 * * * *  user1 nice /opt/rrdtool/scripts/jvm_memory_graph.sh hour > /dev/null 2>&1
# */5 * * * *  user1 nice /opt/rrdtool/scripts/jvm_memory_graph.sh day > /dev/null 2>&1
# */15 * * * * user1 nice /opt/rrdtool/scripts/jvm_memory_graph.sh week > /dev/null 2>&1
# */30 * * * * user1 nice /opt/rrdtool/scripts/jvm_memory_graph.sh month > /dev/null 2>&1
# 00 * * * *   user1 nice /opt/rrdtool/scripts/jvm_memory_graph.sh year > /dev/null 2>&1

#--------------------------------------------
# Nothing to change below this line
#--------------------------------------------

HOSTNAME=`hostname --fqdn`

# Java Process command line options: jcmd <PID> VM.command_line

TYPE=$1
if [ -z "$TYPE" ]
then
   echo "Specify Option: <server_ram_total|server_ram_used|jvm_heap_max|jvm_heap_used|jvm_gc>"
   exit 0
fi

PID=`ps -e -o pid -o args | grep "$JVM_IDENTIFIER" | grep "XX:" | awk -F' ' '{print $1}'`

case $TYPE in
   server_ram_total)
      # Total memory allocated to server (GB)
      OUTPUT=`free -g | grep "Mem" | awk -F' ' '{print $2}'`
   ;;
   server_ram_used)
      # Currently used server memory (GB)
      USED=`free -g | grep "Mem" | awk -F' ' '{print $3}'`
      CACHED=`free -g | grep "Mem" | awk -F' ' '{print $7}'`
      OUTPUT=$((USED-CACHED)) 
   ;; 
   jvm_heap_max)
      # Maximum JVM memory allocation (GB)
      OUTPUT=`ps -e -o args | grep "$JVM_IDENTIFIER" | grep --only-matching " -Xmx[0-9]*g " | grep --only-matching "[0-9]*"`
      #OUTPUT=`$JCMD $PID VM.flags | grep "XX:" | grep --only-matching "MaxHeapSize=[0-9]* " | grep --only-matching "[0-9]*"`
      #OUTPUT=$((OUTPUT/1024/1024/1024)) 
   ;;
   jvm_heap_used)
      # Current JVM memory usage (GB)
      if [ -z "$PID" ]
      then
         echo "U" 
         exit 0
      fi
      JSTAT=`$JSTAT -gc $PID | grep -v GCT`
      S0U=`echo $JSTAT | awk -F' ' '{print $3}' | awk -F'.' '{print $1'}`
      S1U=`echo $JSTAT | awk -F' ' '{print $4}' | awk -F'.' '{print $1'}`
      EU=`echo $JSTAT | awk -F' ' '{print $6}' | awk -F'.' '{print $1'}`
      OU=`echo $JSTAT | awk -F' ' '{print $8}' | awk -F'.' '{print $1'}`
      PU=`echo $JSTAT | awk -F' ' '{print $10}' | awk -F'.' '{print $1'}`
      OUTPUT=$((S0U+S1U+EU+OU+PU))  # JVM HEAP is total Utilization (see notes at end of script)
      OUTPUT=$((OUTPUT/1024/1024))
   ;;
   jvm_gc)
      # Timestamp of Garbage Collection
      if [ -z "$PID" ]
      then
         echo "U"
         exit 0
      fi
      JSTATOUT=`$JSTAT -gc $PID | grep -v GCT`
      #echo "$JSTATOUT" >&2
      YGC=`echo $JSTATOUT | awk -F' ' '{print $11}' | awk -F'.' '{print $1'}`
      FGC=`echo $JSTATOUT | awk -F' ' '{print $13}' | awk -F'.' '{print $1'}`
      #GC=$((YGC+FGC))
      GC=$FGC
      LASTGC=`cat "$GCLOG"`
      if [ "$GC" -gt "$LASTGC" ]
      then
         # Number of GC events in last five minutes
         OUTPUT=$(($GC-$LASTGC))
      else
         OUTPUT="0"
      fi
      # Remember last $GC value for comparison next time
      echo "$GC" > "$GCLOG"
   ;;
esac

# $OUTPUT is in KB
if [ -z $OUTPUT ]
then
	echo "U"       #RRDTool format for "unknown" or "no response"
else
        echo $OUTPUT
fi

exit 0


OpenJDK NOTES:

http://karunsubramanian.com/java/5-not-so-easy-ways-to-monitor-the-heap-usage-of-your-java-application/

S0C  Current survivor space 0 capacity (KB).
S1C  Current survivor space 1 capacity (KB).
S0U  Survivor space 0 utilization (KB).
S1U  Survivor space 1 utilization (KB).
EC  Current eden space capacity (KB).
EU  Eden space utilization (KB).
OC  Current old space capacity (KB).
OU  Old space utilization (KB).
PC  Current permanent space capacity (KB).
PU  Permanent space utilization (KB).
YGC  Number of young generation GC Events.
YGCT  Young generation garbage collection time.
FGC  Number of full GC events.
FGCT  Full garbage collection time.
GCT  Total garbage collection time.

When you add all the ‘utilizations’ i.e OU,PU,EU,S0U,S1U, you get the total Heap utilization.


Oracle JDK Notes:

http://www.thecoderscorner.com/team-blog/java-and-jvm/optimisation/8-gc-monitoring-in-java-with-jstat

  S0     S1     E      O      P     YGC     YGCT    FGC    FGCT     GCT   

First set of columns (S0, S1, E, O, P) describes the utilisation of the various memory heaps (Survivor heaps, Eden - young generation, Old generation and Permanent heap space).

Next, (YGC and YGCT) show the number of young (Eden) space collections and total time taken so far doing these collections.

Columns (FCG, FGCT) show the number and time taken doing old space collections.

Lastly, GCT shows the total time taken performing garbage collection so far.

