#!/bin/ash
#
# Written for VMware ESXi 5.x
#
# Brandon Gant
# Created: 2013-06-05
# Updated: 2013-10-03
#
# This script will create a VAAI "balloon file" in the VMFS volume to
# UNMAP data that has been deleted and shrink thin VMFS volumes.
#
# http://blogs.vmware.com/vsphere/2012/04/vaai-thin-provisioning-block-reclaimunmap-in-action.html
#
# Most articles documenting this command use 60% of free space. My 2TB VMFS-5 Test volume on 
# 7200rpm disk generates errors about truncating the .vmfsBalloon file when I set it to 90%,
# but this apparently just causes the process to take longer while it tries to figure out the 
# best size of the file (which takes 40 minutes for a 1.4TB .vmfsBalloon file):
# http://cormachogan.com/2013/05/14/heads-up-unmap-considerations-when-reclaiming-more-than-2tb/
#
# My 1TB VMFS-5 Production volumes on Solid-State Disk do not have errors at 90% and complete
# in about 15 seconds.

PERCENTAGE_OF_FREE_SPACE="60"
DIR="/vmfs/volumes"


### Find and list the "symbolic link" VMFS names
VMFS_VOLUMES=`find $DIR -maxdepth 1 -type l | awk -F'/' '{print $4}' | sort`

VMFS_VOLUME_CHOICES () { 
   echo                                       
   echo "Available <vmfs> choices on this server are:"
   echo
   echo "$VMFS_VOLUMES"
   echo
}

RUN_VAAI_UNMAP () {
if [ -n "$VMFS" ]
then

   if [ -e "$DIR/$VMFS" ]
   then
      date
      echo "$DIR/$VMFS"
      
      # Check to make sure this volume can handle VAAI UNMAP                         
      # NOTE: The space in "$VMFS " to make sure it doesn't grab other volumes with similar names
      NAA=`esxcli storage vmfs extent list | grep "$VMFS " | awk -F' ' '{print $4}'`
      echo "$NAA"                                                                    
      THIN=`esxcli storage core device list -d $NAA | grep "Thin"`            
      echo "$THIN"                                                
      VAAI=`esxcli storage core device list -d $NAA | grep "VAAI"`
      echo "$VAAI"                                                            
      UNMAP=`esxcli storage core device vaai status get -d $NAA | grep "Delete Status"`
      echo "$UNMAP"                                                                    
      
      # Check to see if the chosen VMFS volume supports VAAI UNMAP
      # NOTE: the space in " supported" helps grep distinguish between the words supported and unsupported
      if [ `echo "$THIN" | grep -c " yes"` = 1 ] && [[ `echo "$VAAI" | grep -c " supported"` = 1 ]] && [[ `echo "$UNMAP" | grep -c " supported"` = 1 ]]
      then                                                                                                                                             
         echo
         echo "Volume is ready to run VAAI UNMAP command..."                                                                                                                
         echo                                                                          
         # NOTE: the $ at the end distinguishs names like "vmdisk" and "vmdisk-test"
         df -h | egrep "Mounted |$DIR/$VMFS$"
         echo
         
         # Check to see if a .vmfsBalloon file already exists on this volume
         BALLOON=`ls -1 $DIR/$VMFS/.vmfsBalloon* 2> /dev/null`
         if [ -n "$BALLOON" ]
         then
            echo "ERROR: Balloon file already exists in this VMFS volume: $BALLOON"
            echo
         else
            # Now we go into the volume and create the .vmfsBalloon file...
            cd $DIR/$VMFS                                                                           
            time /sbin/vmkfstools -y $PERCENTAGE_OF_FREE_SPACE
            echo
            echo "VAAI UNMAP operation complete!"
            echo
         fi
      else                                                                             
         echo "VAAI UNMAP does not appear to be supported on this volume... Exiting"                                                                   
         echo                                                                                                                                          
      fi      
      
   else
      echo
      echo "$DIR/$VMFS does not exist!"
      VMFS_VOLUME_CHOICES
   fi
   
else
   echo
   echo "Usage: $0 <vmfs|all>"
   VMFS_VOLUME_CHOICES
fi
}

case $1 in
   all)
      # Run VAAI Unmap on all VMFS volumes
      for VMFS in $VMFS_VOLUMES
      do
         echo "================================================="
         RUN_VAAI_UNMAP
         echo "================================================="
      done         
   ;;
   *)
      # Run VAAI Unmap on a specific volume
      VMFS="$1"
      RUN_VAAI_UNMAP
   ;;
esac

exit 0
