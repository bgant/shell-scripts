#!/bin/ash
# 
# Script for BusyBox on Alpine Linux
#
# Linked to /etc/periodic/weekly/qcow2-backup for 3AM Saturday backups (crontab -l)
# but only keeps one backup each month
#
# ln -s qcow2-backup.sh /etc/periodic/weekly/qcow2-backup  <-- NO .sh or will not work
# run-parts /etc/periodic/weekly                           <-- Test that cron is running script properly
#
###################################
# Virtual Machine files to Backup #
###################################

if [ -n "$1" ]  # string is not null
then
    VMLIST=$1
else
    VMLIST="Prod-OPNsense Prod-Wiki-Gant alpine-arpwitch Prod-BURP"
fi
echo $VMLIST

###################################

SOURCE="/zfs-pool"
DESTINATION="/eSATA1/qcow2-backups"
#DATE=$(date +%W)  # Weekly numbers
DATE=$(date +%m)   # Monthly numbers

# Check to see if /eSATA1 is mounted properly
umount /eSATA1
sleep 2
mount /eSATA1

if [ ! -e $DESTINATION ]
then 
    echo "$DESTINATION does not exist"
    echo "/eSATA1 is not mounted properly... Exiting"
    exit 1
fi

# Ash function to handle VM shutdown
vmshutdown () {
     virsh shutdown $VM 
     while [ $(virsh list | grep 'running' | grep -c "$1 ") -eq 1 ]
     do                                                             
        echo "   --- Waiting for $VM to shutdown..."                       
        sleep 3                              
     done                                    
     echo
} 

echo

for VM in $VMLIST
do
  POWER=$(virsh list | awk -F' ' '{print $2}' | grep -c $VM$)  # Check if running
  if [ "$POWER" -ne "0" ]  # Only shutdown if it was running
  then
      vmshutdown $VM
  fi
  echo "Copying $VM.qcow2 to $DESTINATION/$VM-$DATE.qcow2"
  rsync --sparse --archive --progress $SOURCE/$VM.qcow2 $DESTINATION/$VM-$DATE.qcow2
  if [ "$POWER" -ne "0" ]  # Only start if it was on before
  then
      virsh start $VM
  fi
  echo "Compressing $DESTINATION/$VM-$DATE.qcow2 with gzip..."
  gzip -f $DESTINATION/$TODAY/$VM-$DATE.qcow2
done

exit 0


##########
### NOTES: I forgot rsync copies files that changed. It copies the entire changed file.
###        The following would work with a directory of small files.

  TODAY=$(date +%Y-%m-%d)

  # No need to run backup again Today if it is already done...     
  if [ -e $DESTINATION/$TODAY/$VM.qcow2.gz ]                              
  then                                                             
      echo "$VM backup for Today already exists... Exiting."       
      echo                                                         
      exit 1                                                       
  fi   

  # See if any previous backups exist to do incremental rsync...   
  if [ -e $DESTINATION/$(ls -1t $DESTINATION/ | head -n1)/$VM.qcow2 ]
  then                                                               
     echo "Running incremental backup using a previous backup file..."
     echo                                                             
     vmshutdown $VM                                                   
     rsync --inplace --archive --progress --link-dest=$DESTINATION/$(ls -1t $DESTINATION/ | head -n1)/ $SOURCE/$VM.qcow2 $DESTINATION/$TODAY/
     virsh start $VM                                                                                                                         
  else                                                                                                                                       
     echo "Creating initial backup file..."  
     vmshutdown $VM                                                                    
     rsync --sparse --archive --progress $SOURCE/$VM.qcow2 $DESTINATION/$TODAY/               
     virsh start $VM  
  fi

 # Instead of looking for "Yesterday" like most scripts,                                                                                      
 # checking for the last backup taken with "ls -1t | head -n1"                                                                                
 YESTERDAY=$(date -d@"$(( `date +%s` -86400))" +%Y-%m-%d)  

