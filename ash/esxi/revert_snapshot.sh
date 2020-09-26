#!/bin/ash

# This script does the following:
#   - Reverts to the latest snapshot available for a list of VM's in revert_snapshot.list

VM_FILE="/vmfs/volumes/local/scripts/revert_snapshot.list"
VMWARE_CMD="/bin/vim-cmd"

#dump out all virtual machines allowing for spaces now
${VMWARE_CMD} vmsvc/getallvms | sed 's/[[:blank:]]\{3,\}/   /g' | awk -F'   ' '{print "\""$1"\";\""$2"\";\""$3"\""}' |  sed 's/\] /\]\";\"/g' | sed '1,1d' > /tmp/vms_list 

for VM_NAME in `cat "${VM_FILE}" | grep -v "#" | sed '/^$/d' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`;
do
  VM_ID=`grep -E "\"${VM_NAME}\"" /tmp/vms_list | awk -F ";" '{print $1}' | sed 's/"//g'`
  echo
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo "+ VM_NAME:  ${VM_NAME}   VM_ID:  ${VM_ID}"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo
  
  # Check to see if VM exists...
  if [ -z ${VM_ID} ];
  then
     echo "ERROR: Failed to locate and extract VM_ID for ${VM_NAME}"
     echo
  else
  
     # This one just counts how many snapshots there currently are and reverts to the last one
     LASTSNAPSHOT=`/bin/vim-cmd vmsvc/get.snapshotinfo $VM_ID | grep -c vim.VirtualMachine`
  
     echo "Reverting to Last Snapshot (Snapshot No. $LASTSNAPSHOT)"
  
     # Snapshot numbers start at zero
     LASTSNAPSHOT=$(($LASTSNAPSHOT-1))
  
     /bin/vim-cmd vmsvc/snapshot.revert $VM_ID 0 $LASTSNAPSHOT
     sleep 10
     /bin/vim-cmd vmsvc/power.on $VM_ID
  
  fi
  
done

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"                                                                                                  
echo "+ End of revert_snapshot.sh script: `date`"                                                                                                                          
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 
      
exit
