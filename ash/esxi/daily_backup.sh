#!/bin/ash
#
# VMware ESXi Backup Script
# Created by Brandon Gant
# Last Modified 2012-01-07

######################################################################################################################
# This script does the following:
#   - Creates daily live snapshots (without RAM) Monday through Saturday
#   - Does the following on Sunday
#        - Performs a full backup using vmkfstools while machine is running
#        - Deletes all snapshots
#        - Creates a Sunday snapshot
#        - Removes old backups
#
# Restores are by vmkfstools only. The vmx file is only for reference when re-creating the VM.
######################################################################################################################

######################################################################################################################
# To utilize "Thin" provisioning properly, you may want to zero out any unused space on your VM before backup.
# When a file is deleted, the metadata is removed but all the data in the file remains on disk. VMware has no way
# to know that this data is no longer needed, so it keeps it when it builds the "Thin" disk backup. Run the
# following command to zero out all the unused file space on the root file system:
#
#    dd if=/dev/zero of=~/wipe.file; rm ~/wipe.file
#
# There is no need to use sudo. It will write the file until the disk fills up, then delete the file.
######################################################################################################################


BACKUP_DIR="/vmfs/volumes/vmhost-tc-external/backup"
VM_FILE="/vmfs/volumes/vmhost-tc-local/scripts/daily_backup.list"
BACKUP_ROTATION="4"
DAY=`date +%w`
SEC="5"

# Test Sunday Backup
#DAY="0"

#dump out all virtual machines allowing for spaces now
/bin/vim-cmd vmsvc/getallvms | sed 's/[[:blank:]]\{3,\}/   /g' | awk -F'   ' '{print "\""$1"\";\""$2"\";\""$3"\""}' |  sed 's/\] /\]\";\"/g' | sed '1,1d' > /tmp/vms_list 

for VM_NAME in `cat "${VM_FILE}" | grep -v "#" | sed '/^$/d' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//'`;
do
  VM_ID=`grep -E "\"${VM_NAME}\"" /tmp/vms_list | awk -F ";" '{print $1}' | sed 's/"//g'`
  VM_DISK=`grep -E "\"${VM_NAME}\"" /tmp/vms_list | awk -F'[' '{print $2}' | awk -F']' '{print $1}'`
  echo
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo "+  VM_NAME: ${VM_NAME}"
  echo "+    VM_ID: ${VM_ID}"
  echo "+  VM_DISK: ${VM_DISK}"
  echo "+     Time: `date`"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo
  
  # Check to see if VM exists...
  if [ -z ${VM_ID} ];
  then
     echo "ERROR: Failed to locate and extract VM_ID for ${VM_NAME}"
     echo
  
  # Snapshots Only every day except Sunday
  elif [ "${DAY}" -ne 0 ];
  then
     echo -n "Taking Live Daily Snapshot...  "
     /bin/vim-cmd vmsvc/snapshot.create ${VM_ID} `date +%a-%Y-%m-%d-%H%M` "Daily Snapshot Backup" 0 1
     echo
     sleep ${SEC}
              
  # Full Backup on Sundays
  elif [ "${DAY}" -eq 0 ]; 
  then
      # You cannot copy from the latest snapshot on a running virtual machine
      # (current disk writes are being written to it)
      
      # Temporary Snapshots
      echo -n "Creating backup-snapshot...      "
      /bin/vim-cmd vmsvc/snapshot.create ${VM_ID} backup-snapshot "Temp Snapshot for Full Backup" 0 1 
      echo -n "Creating running-vm-snapshot...  "
      /bin/vim-cmd vmsvc/snapshot.create ${VM_ID} running-vm-snapshot "Temp Snapshot for Running VM" 0 1 
      echo
      
      # Count the total number of snapshots and subtract one to get the "backup_snapshot"
      BACKUP_SNAPSHOT=`/bin/vim-cmd vmsvc/get.snapshotinfo $VM_ID | grep -c vim.VirtualMachine`
      BACKUP_SNAPSHOT=$(($BACKUP_SNAPSHOT-1))
      
      # Create a backup of the virtual machine from the backup-snapshot while the virtual machine is still running...
      mkdir -p ${BACKUP_DIR}/${VM_NAME}
      VM_SOURCE="/vmfs/volumes/${VM_DISK}/${VM_NAME}/${VM_NAME}-*${BACKUP_SNAPSHOT}.vmdk"
      VM_BACKUP="${BACKUP_DIR}/${VM_NAME}/${VM_NAME}-`date +%Y-%m-%d`.vmdk"
      echo "Source: ${VM_SOURCE}"
      vmkfstools -d thin -i ${VM_SOURCE} ${VM_BACKUP}
      cp /vmfs/volumes/${VM_DISK}/${VM_NAME}/${VM_NAME}.vmx ${BACKUP_DIR}/${VM_NAME}/${VM_NAME}-`date +%Y-%m-%d`.vmx
      echo "Backup Created: ${VM_BACKUP}"
      
      # According to the ghettoVCB website, Busybox cannot reliably handle compressing files larger than 8GB. - Brandon
      VM_FLAT="${BACKUP_DIR}/${VM_NAME}/${VM_NAME}-`date +%Y-%m-%d`-flat.vmdk"
      DISK_SIZE=`du -k "${VM_FLAT}" | awk -F' ' '{print $1}'`
      if [ ${DISK_SIZE} -le 8000000 ];
      then
         echo "Backup file is ${DISK_SIZE}KB (less than 8GB)... Compressing Backup *-flat.vmdk file..."
         gzip ${VM_FLAT}
      else
         echo "Backup file is ${DISK_SIZE}KB (greater than 8GB)... Backup file will not be compressed."
      fi
      
      # Delete old backups
      BACKUP_TOTAL=`ls -1 ${BACKUP_DIR}/${VM_NAME}/${VM_NAME}*.vmx | wc -l` 
      echo "Total ${VM_NAME} Backups: ${BACKUP_TOTAL}" 
      if [ "${BACKUP_TOTAL}" -ge "${BACKUP_ROTATION}" ] 
      then 
         echo "Removing older backups..." 
         BACKUP_ROTATION=$(($BACKUP_ROTATION+1))
         find ${BACKUP_DIR}/${VM_NAME}/ -name ${VM_NAME}-*.vmx | tail -n +${BACKUP_ROTATION} | xargs rm
         find ${BACKUP_DIR}/${VM_NAME}/ -name ${VM_NAME}-*.vmdk* | grep -v flat | tail -n +${BACKUP_ROTATION} | xargs rm
         find ${BACKUP_DIR}/${VM_NAME}/ -name ${VM_NAME}-*.vmdk* | grep flat | tail -n +${BACKUP_ROTATION} | xargs rm
      fi 
      echo 
      
      # Delete all snapshots after Full Backup
      echo -n "Removing snapshots...       "
      /bin/vim-cmd vmsvc/snapshot.removeall ${VM_ID}
      echo
      
      # Create a snapshot for Sunday
      echo -n "Taking Live Daily Snapshot...    "
      /bin/vim-cmd vmsvc/snapshot.create ${VM_ID} `date +%a-%Y-%m-%d-%H%M` "Daily Snapshot Backup" 0 1
      echo
      
  fi
  
done

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 
echo "+ Finished: `date`" 
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" 
      
exit
