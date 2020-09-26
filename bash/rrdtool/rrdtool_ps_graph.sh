#!/bin/bash


#######################################################################################################################
#  Subroutine: Generate rrdtool graph command definitions (DEF) for each RRD file
#######################################################################################################################
generate_DEF_list () {

for FNAME in $FNAMES
do

if [ -z "$SERVERS" ]
then
   SERVERS=`hostname --short`
fi

for SERVER in $SERVERS
do

if [ $SERVER == "t2000-2" ]
then
   HEXCOLOR="22FFFF" 
elif [ $SERVER == "t5120-ppsb1" ]
then 
   HEXCOLOR="22FFFF"
elif [ $SERVER == "t5140-1" ]
then
   HEXCOLOR="FFFF00"
elif [ $SERVER == "t5140-ppsb1" ]
then
   HEXCOLOR="FFFF00"
elif [ $SERVER == "t5140-ppsb2" ]
then
   HEXCOLOR="22FFFF"
else
   HEXCOLOR="22FF00"  # Green
   #HEXCOLOR="22FFFF"  # Blue
   #HEXCOLOR="FFFF00"  # Orange
   #HEXCOLOR="FFCC33"  # Red
fi

if [ -z "$LIBS" ]
then 
   LIBS="$LIBLIST"
fi
for LIB in $LIBS 
do

  FILE="/opt/rrdtool/rrdfiles/"$SERVER"_"$LIB"_"$FNAME".rrd"
  if [ -e "$FILE" ]
  then
        
        echo "Reading Data:   $FILE"

        shade_HEXCOLOR

        COMMAND="${COMMAND} DEF:"$SERVER"_"$LIB"_"$FNAME"=/opt/rrdtool/rrdfiles/"$SERVER"_"$LIB"_"$FNAME".rrd:Data:AVERAGE"

        # The first definition needs to be "AREA" instead of "STACK"
        if [ -z "$AREA" ]
        then 
           COMMAND="${COMMAND} AREA"
           AREA="1"
        else
           COMMAND="${COMMAND} STACK"
        fi

        COMMAND="${COMMAND}:"$SERVER"_"$LIB"_"$FNAME"#$HEXCOLOR:"
  fi
done
done
done
}
#######################################################################################################################


#######################################################################################################################
# Subroutine: Gradually change the AREA color when graphing all libraries
#######################################################################################################################
shade_HEXCOLOR () {
DECCOLOR=$( printf "%d" 0x${HEXCOLOR} )
DECCOLOR=$(($DECCOLOR - 512))
HEXCOLOR=$( printf "%X" ${DECCOLOR} )
}
#######################################################################################################################



HOSTNAME=`hostname --short`

USAGE="Usage: `basename $0` --timespan=<hour|day|week|month|year> --process=<process name> [--library=<three-letter code>]"

# We want at least one command line argument
if [ $# -eq 0 ]
then
        echo $USAGE >&2
        exit 1
fi

# Parse command line arguments
for PARAM; do
   CONTROL=`echo $PARAM | cut -d= -f1`
   OPTIONS=`echo $PARAM | cut -d= -f2`

   case $CONTROL in
   *timespan) 
       TimeSpan="$OPTIONS"
       echo "TimeSpan: $TimeSpan"
       ;;
   *process)
       FNAMES="$OPTIONS"
       echo "Process: $FNAMES"
       ;;
   *library)
       LIBS="$OPTIONS"
       LIBS=`echo $LIBS | tr "[:lower:]" "[:upper:]"` 
       echo "Library: $LIBS"
       ;;
   *filename)
       GraphName="$OPTIONS"
       echo "Filename: $GraphName"
       ;;
   *server)
       SERVERS="$OPTIONS"
       echo "Server: $SERVERS"
       ;;
   *)
      echo "Invalid command line argument: $CONTROL"
      exit
      ;;
   esac
done

# Verify timespan command line argument is valid
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
echo $USAGE >&2
exit 1;;
esac

Time=`/bin/date +%a" "%b" "%d" "%H"\:"%M"\:"%S`

# Verify process command line argument has been specified
if [ -z "$FNAMES" ] 
then 
   echo "You must specify at least one process to graph"
   exit 1
fi

# Verify library command line argument is valid
LIBLIST=`ls -1 /<DIR> | grep "[A-Z][A-Z][A-Z]db$" | awk -F"d" '{print $1}'`
LIBLIST="$LIBLIST UCC ALL"

if [ -z "$LIBS" ]
then
   Graph="/opt/rrdtool/graphs/ALL_"$FNAMES"_$TimeSpan.png"
   TITLE="Voyager Process Count: $FNAMES"
else
   for LIB in $LIBS
   do
      if [ `echo $LIBLIST | grep -c $LIB` != "1" ]
      then
         echo
         echo "$LIB is not a valid three-letter library code"
         exit 1
      fi
   done
   TITLE="Voyager Process Count: $LIBS $FNAMES"      
fi

# What do we name the graph file if there are multiple command line processes or libraries to graph?
MultipleProcesses=`expr match "$FNAMES" '.*\(\w\s\w\).*'`
if [ -z "$MultipleProcesses" ] && ([ `echo $LIBS | wc -L` == "3" ] || [ -z "$LIBS" ])
then
   if [ -z "$LIBS" ]
   then
      Graph="/opt/rrdtool/graphs/ALL_"$FNAMES"_$TimeSpan.png"
   else
      Graph="/opt/rrdtool/graphs/"$LIBS"_"$FNAMES"_$TimeSpan.png"
   fi
else
   if [ -z $GraphName ]
   then
      echo
      echo "These command line arguments require a custom file name."
      echo -n "What do you want to call this graph: "
      read -e GraphName
   fi
   Graph="/opt/rrdtool/graphs/"$GraphName"_$TimeSpan.png"
fi

COMMAND="rrdtool graph $Graph --start $Start --height=200 --width=795"
COMMAND="${COMMAND} --title=\"$TITLE\" --font TITLE:12: --vertical-label=\"Number of Processes\" --font UNIT:10:"
COMMAND="${COMMAND} --lower-limit=0 --units-exponent 0 --color=BACK#B5B1B1 --color=CANVAS#DDDDDD --color=SHADEB#666666"
#COMMAND="${COMMAND} COMMENT:\s COMMENT:\s COMMENT:\"     \""  

generate_DEF_list

COMMAND="${COMMAND} COMMENT:\"    \" COMMENT:\"  Green=${HOSTNAME}         \" COMMENT:\"        \" COMMENT:\"         \" COMMENT:\"        \" COMMENT:\"Last data entered at $Time\""
#echo $COMMAND

echo
echo -n "Creating Graph: $Graph "
eval $COMMAND
echo

rsync --archive --itemize-changes /opt/rrdtool/graphs/*.png <Your_Web_Server>::html/${HOSTNAME}/

exit


#############################
# Commands to Remember
#############################
#
#  XXX=`expr match "$DB" '.*\([A-Z][A-Z][A-Z]\)db.*'`
#  if [[ $string =~ .*Test.* ]]


