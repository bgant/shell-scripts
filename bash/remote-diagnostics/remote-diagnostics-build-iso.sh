#!/bin/bash
# 
# Built using commands from the following article:
#   http://www.linuxjournal.com/magazine/paranoid-penguin-customizing-linux-live-cds-part-i
#
# Brandon Gant
# 2011-10-19


#====================================#
#  Global Variables                  #
#====================================#

SERVER="remote-diagnostics.<Your_Domain>"
INIT_SCRIPT="remote-diagnostics"
MAIN_SCRIPT="remote-diagnostics-initialization.sh"


#====================================#
#  Download LiveCD base image        #
#====================================#

if [ `grep -c Ubuntu /etc/lsb-release` -le "1" ]
then
   echo "This script only works on Ubuntu"
   exit 0
fi

# The operating system running this script and the LiveCD operating system must match
DISTRIB_RELEASE=`grep DISTRIB_RELEASE /etc/lsb-release | awk -F'=' '{print $2}'`
DISTRO="ubuntu-mini-remix-$DISTRIB_RELEASE-i386.iso"

if [ ! -e ./$DISTRO ]
then
   wget http://www.ubuntu-mini-remix.org/download/$DISTRIB_RELEASE/$DISTRO
fi
chmod 444 $DISTRO


#====================================#
#  Build init.d script               #
#====================================#

cat <<EOF > $INIT_SCRIPT
#!/bin/bash
mv /etc/sudoers /etc/sudoers.disable
chmod 555 /home/ubuntu
cat <<EOF2 > /tmp/loginloop
#!/bin/bash
tail -f /var/log/syslog
EOF2
chmod +x /tmp/loginloop
usermod -s /tmp/loginloop ubuntu
pkill -9 -u ubuntu
while [ -z "\`rsync $SERVER::scripts/$MAIN_SCRIPT\`" ]
do 
   echo "Waiting for network connection..."
   sleep 15
   
   #--- using eth0?
   #/etc/init.d/networking restart
   #--- using wlan0?
   /opt/wireless.sh

done
   rsync --archive $SERVER::scripts/$MAIN_SCRIPT /tmp/
   chmod u+x /tmp/$MAIN_SCRIPT
   ( /tmp/$MAIN_SCRIPT > /tmp/remote-diagnostics.log ) &
exit 0
EOF

chmod 755 $INIT_SCRIPT


#====================================#
#  Upgrade and Repackage LiveCD      #
#====================================#

apt-get install squashfs-tools mkisofs
mkdir -p ./isomount ./isonew/squashfs ./isonew/cd ./isonew/custom
mount -o loop ./$DISTRO ./isomount
rsync --exclude=/casper/filesystem.squashfs --archive --itemize-changes ./isomount/ ./isonew/cd
modprobe squashfs
mount -t squashfs -o loop ./isomount/casper/filesystem.squashfs ./isonew/squashfs/
rsync --archive --itemize-changes ./isonew/squashfs/ ./isonew/custom

cp /etc/resolv.conf ./isonew/custom/etc/
cp $INIT_SCRIPT ./isonew/custom/etc/init.d/
cd ./isonew/custom/etc/rc2.d
ln -s ../init.d/$INIT_SCRIPT S99$INIT_SCRIPT
cd ../rc3.d
ln -s ../init.d/$INIT_SCRIPT S99$INIT_SCRIPT
cd ../../../../

chroot ./isonew/custom /bin/sh -c \
      "mount -t proc none /proc/; mount -t sysfs none /sys/; export HOME=/root; \
       apt-get update; apt-get -y dist-upgrade; \
       apt-get -y install wpasupplicant wireless-tools software-properties-common; \
       add-apt-repository universe; apt-get update; \
       apt-get -y install smokeping curl bc tcptraceroute; \
       apt-get -f -y install; \
       apt-get -y autoremove; apt-get clean; \
       rm -rf /tmp/*; umount /proc/; umount /sys/;" 

rm ./isonew/custom/etc/resolv.conf

cp ./wpa_supplicant.conf ./isonew/custom/etc/wpa_supplicant/
cp ./wireless.sh ./isonew/custom/opt/

chmod +w ./isonew/cd/casper/filesystem.manifest
chroot ./isonew/custom dpkg-query -W --showformat='${Package} ${Version}\n' > ./isonew/cd/casper/filesystem.manifest
cp ./isonew/cd/casper/filesystem.manifest ./isonew/cd/casper/filesystem.manifest-desktop

mksquashfs ./isonew/custom ./isonew/cd/casper/filesystem.squashfs

rm ./isonew/cd/md5sum.txt
cd ./isonew/cd
find . -type f -print0 | xargs -0 md5sum > md5sum.txt

mkisofs -r -V "Remote Diagnostics" -b isolinux/isolinux.bin -c isolinux/boot.cat -cache-inodes \
   -J -l -no-emul-boot -boot-load-size 4 -boot-info-table -o ../../remote-diagnostics-$DISTRIB_RELEASE-i386-`date +%Y-%m-%d`.iso .
cd ../../
chmod 444 ./remote-diagnostics-$DISTRIB_RELEASE-i386-*.iso

sleep 10
umount /dev/loop0
umount /dev/loop1
sleep 3
rm -r ./isomount
rm -r ./isonew
rm $INIT_SCRIPT
#rm ./$DISTRO

echo "Build Complete"
exit 0
