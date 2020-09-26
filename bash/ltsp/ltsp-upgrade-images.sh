#!/bin/bash
#
# This script upgrades all LTSP Boot images

CROSSOVER="crossover_13.1.2-1.deb"

LIST=`ls -1 /opt/ltsp | grep -v images | grep -v lost`

for CHROOT in $LIST
do

echo
echo

if [[ "$CHROOT" =~ "amd64" ]]
then 
  ARCH="amd64"
elif [[ "$CHROOT" =~ "i386" ]]
then 
  ARCH="i386"
else
  PS3="Choose (1-2):"
  echo "Choose from the list below."
  select ARCH in amd64 i386
  do
        break
  done
  if [ -z $ARCH ]
  then
      echo
      echo "Not a valid choice... exiting script"
      echo
      exit 1
  fi
fi

echo
echo "############################################################"
echo "CHROOT: $CHROOT"
echo "ARCH: $ARCH"


echo
echo "############################################################"
echo "## Setting permissions..."
# Allow passwords to work on the client too...
cp -v /etc/shadow /opt/ltsp/$CHROOT/etc/shadow.ltsp

# Special sudoers file that grants all staff/users sudo to root on
# the thin or fat client operating system (but not the LTSP server)
# Users on the server MUST be in the "users" group (guid 100)!!!
cp -v /etc/ltsp/sudoers /opt/ltsp/$CHROOT/etc/

# Change default xscreensaver settings
sudo perl -p -i -e "s/0:10:00/4:00:00/g" /opt/ltsp/$CHROOT/etc/X11/app-defaults/XScreenSaver-nogl
sudo perl -p -i -e "s/random/blank/g" /opt/ltsp/$CHROOT/etc/X11/app-defaults/XScreenSaver-nogl

echo
echo "############################################################"
echo "## Setting up printing..."

# The following uses a "hammer" and only allows printing via the server
#echo "ServerName 192.168.0.103" > /opt/ltsp/$CHROOT/etc/cups/client.conf

# I need to somehow install the Dymo drivers:
#   For now, chroot into /opt/ltsp/fat-i386 and do cd dymo; ./configure; make; make install
# lpadmin -p Dymo -v usb://...; cupsenable Dymo; cupsaccept Dymo

cp -v /etc/ltsp/printer-drivers/*.ppd /opt/ltsp/$CHROOT/usr/share/cups/model/
cp -v /etc/ltsp/printer-drivers/raster2dymo* /opt/ltsp/$CHROOT/usr/lib/cups/filter/

# Add remote printing support
perl -p -i -e "s/Browsing Off/Browsing On/g" /opt/ltsp/$CHROOT/etc/cups/cupsd.conf
perl -p -i -e "s/# BrowseAllow cups.example.com/BrowseAllow 128.174.138.64\/26/g" /opt/ltsp/$CHROOT/etc/cups/cups-browsed.conf

# Install Epson Printer/Scanner Packages for Dennis' Epson WP-4530 All-in-One
# Download .deb files from http://download.ebz.epson.net
#echo "## Installing Epson i386 packages..."
#cp /etc/ltsp/epson-inkjet*.deb /opt/ltsp/$CHROOT/opt/
#chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/epson-inkjet-printer-201113w_*_$CHROOT.deb"
#chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/epson-inkjet-printer-escpr_*_$CHROOT.deb"
#cp /etc/ltsp/iscan*.deb /opt/ltsp/$CHROOT/opt/
#chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/iscan-data_*_all.deb"
#chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/iscan_*_$CHROOT.deb"
#chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/iscan-network-nt_*_$CHROOT.deb"
#rm /opt/ltsp/$CHROOT/opt/*.deb

echo
echo "############################################################"
echo "## Installing CrossOver $CROSSOVER package..."
cp -v /etc/ltsp/$CROSSOVER /opt/ltsp/$CHROOT/opt/
chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/$CROSSOVER"
rm -v /opt/ltsp/$CHROOT/opt/$CROSSOVER
# Using an LTSP client, register using e-mail and password to 
# generate license files in /opt/cxoffice/etc/. Then copy the new
# files to the /etc/ltsp/ folder on the server. 
cp -v /etc/ltsp/crossover_license.sig /opt/ltsp/$CHROOT/opt/cxoffice/etc/license.sig
cp -v /etc/ltsp/crossover_license.txt /opt/ltsp/$CHROOT/opt/cxoffice/etc/license.txt

echo
echo "############################################################"
echo "## Installing Google Earth..."
# Install Google Earth package
#   To build new version of .deb:
#      sudo apt-get install googleearth-package
#      make-googleearth-package --force
#cp -v /etc/ltsp/googleearth_*.deb /opt/ltsp/$CHROOT/opt/
#chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/googleearth_*.deb"

echo
echo "############################################################"
echo "## Reconfiguring operating system files..."

# Change Login Background
mv -v /opt/ltsp/$CHROOT/usr/share/ldm/themes/xubuntu/bg.png /opt/ltsp/$CHROOT/usr/share/ldm/themes/xubuntu/bg-xubuntu.png
mv -v /opt/ltsp/$CHROOT/usr/share/ldm/themes/xubuntu/logo.png /opt/ltsp/$CHROOT/usr/share/ldm/themes/xubuntu/logo-xubuntu.png
cp -v /etc/ltsp/bg.png /opt/ltsp/$CHROOT/usr/share/ldm/themes/xubuntu/bg.png
cp -v /etc/ltsp/logo.png /opt/ltsp/$CHROOT/usr/share/ldm/themes/xubuntu/logo.png

# Check for lts.conf file
if [ ! -e /var/lib/tftpboot/ltsp/$CHROOT/lts.conf ]
then
   cp -v /etc/ltsp/lts.conf /var/lib/tftpboot/ltsp/$CHROOT/lts.conf
fi

# Add Ethernet drivers for Shuttle XS35V2 devices
#if [[ `grep -c jme /opt/ltsp/$CHROOT/etc/initramfs-tools/modules` == "0" ]]
#then
#   echo jme | tee -a /opt/ltsp/$CHROOT/etc/initramfs-tools/modules
#fi
#chroot /opt/ltsp/$CHROOT/ /usr/sbin/update-initramfs -u
#chroot /opt/ltsp/$CHROOT/ /usr/share/ltsp/update-kernels

# Add SpiderOak.com encrypted cloud storage
#echo
#echo "############################################################"
#echo "## Installing SpiderOak encrypted cloud storage package..."
#cp -v /etc/ltsp/spideroakone_6.0_$CHROOT.deb /opt/ltsp/$CHROOT/opt/
#chroot /opt/ltsp/$CHROOT/ /bin/sh -c "dpkg -i /opt/spideroakone_6.0_$CHROOT.deb"
#rm -v /opt/ltsp/$CHROOT/opt/spideroakone_6.0_$CHROOT.deb

# Add Tresorit.com encrypted cloud storage
echo
echo "############################################################"
echo "## Installing Tresorit encrypted cloud storage package..."
#cp -v /etc/ltsp/tresorit_installer.run /opt/ltsp/$CHROOT/opt/
wget -O /opt/ltsp/$CHROOT/opt/tresorit_installer.run "https://installerstorage.blob.core.windows.net/public/install/tresorit_installer.run"
chroot /opt/ltsp/$CHROOT/ /bin/sh -c "./tresorit_installer.run"
rm -v /opt/ltsp/$CHROOT/opt/tresorit_installer.run

echo
echo "############################################################"
echo "## Upgrading LTSP image..."
chroot /opt/ltsp/$CHROOT/ /bin/sh -c \
      "mount -v -t proc proc /proc; env LTSP_HANDLE_DAEMONS=false; \
       apt-get update; \
       apt-get --yes --fix-broken install; \
       apt-get --yes dist-upgrade; apt-get --yes autoremove; apt-get clean; \
       umount -v /proc"
#       apt-get update; \
#       apt-get --yes install ttf-mscorefonts-installer --quiet; \
#       add-apt-repository --yes ppa:noobslab/themes; \
#       add-apt-repository --yes ppa:noobslab/icons; \
#       apt-get --yes install win-themes win-icons; \

echo
echo "############################################################"
echo "## Create new LTSP image file..."
ltsp-update-image --no-backup $CHROOT

echo
echo "## $CHROOT dist-upgrade complete"
echo

done

echo "## All clients upgraded"
echo
exit 0
