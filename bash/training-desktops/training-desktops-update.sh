#!/bin/bash
#
# Brandon Gant 
# 2014-02-08
#
# This script is run by the Root account at startup.
#
# Watch this script output with the following commands:
#   CtrL+Alt+F1
#   tail -f /tmp/check-for-updates.log
#

UPDATE="No"
LTSUPGRADE="No"

SERVER="<Your_rsync_Host_Server>"
SSID="<Your_Wifi_SSID"

RSYNC="rsync --perms --itemize-changes"

export PATH=$PATH:/usr/sbin:/sbin

echo "Deleting previous Guest accounts..."
sed -i '/guest/d' /etc/passwd
sed -i '/guest/d' /etc/shadow

while [ `nice rsync $SERVER:: | grep -c training-desktops` -lt "1" ] 
do
   echo
   echo "Waiting for network connection..."
   echo
   sleep 1
done 

echo
echo "Making sure Firewall is running..."
/usr/sbin/ufw default deny
/usr/sbin/ufw enable

echo
echo "Checking for New root scripts..."
$RSYNC $SERVER::training-desktops/check-for-updates.sh /opt/ | grep 'f\.\.T' || touch /tmp/reboot
$RSYNC $SERVER::training-desktops/rdesktop.sh /opt/ | grep 'f\.\.T' || touch /tmp/reboot
$RSYNC $SERVER::training-desktops/fork.sh /opt/ | grep 'f\.\.T' || touch /tmp/reboot
if [ -e /tmp/reboot ]
then
  echo
  echo "Rsync found updated files... Rebooting..."
  /sbin/init 6
  exit 0
fi

if [[ ( "$UPDATE" = "Yes" ) || ( "$LTSUPGRADE" = "Yes" ) ]] 
then
echo
echo "Installing Packages..."
apt-get update
while [ "$?" != "0" ]
do
  # If the update is locked, wait for it to unlock
  sleep 5
  apt-get update
done
# dpkg does not work without "sudo" in Ubuntu 14.04
rm /etc/apt/apt.conf.d/50unattended-upgrades.ucf-dist
sudo apt-get --yes --fix-broken install
sudo dpkg --configure -a
sudo apt-get --yes dist-upgrade
sudo apt-get --yes install lxde rdesktop freerdp-x11
sudo /etc/init.d/apparmor stop
update-rc.d -f apparmor remove
sudo apt-get --yes remove clipit
sudo apt-get --yes remove cups cups-browsed
sudo apt-get --yes remove thunderbird libreoffice-core
sudo apt-get --yes autoremove
sudo pt-get --yes clean
fi

if [ "$LTSUPGRADE" = "Yes" ]
then
echo
echo "Installing Next LTS Release..."
sed -i 's/Prompt=never/Prompt=lts/g' /etc/update-manager/release-upgrades
# dpkg does not work without "sudo" in Ubuntu 14.04
#sudo do-release-upgrade -f DistUpgradeViewNonInteractive
echo "debconf debconf/frontend select noninteractive" | debconf-set-selections
$RSYNC $SERVER::training-desktops/autostart.16.04 /etc/xdg/lxsession/LXDE/autostart
sudo sh -c 'echo "Y\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\nY\n" | DEBIAN_FRONTEND=noninteractive /usr/bin/do-release-upgrade'
fi

echo
echo "Disabling Updates and Notifications..."
sed -i 's/X-GNOME-Autostart-Delay=60/X-GNOME-Autostart-enabled=false/' /etc/xdg/autostart/update-notifier.desktop
mv /etc/xdg/autostart/ubuntuone-launch.desktop /root/
mv /etc/xdg/autostart/ubuntu-online-tour-checker.desktop /root/
mv /usr/bin/ubuntuone-control-panel-qt /root/

echo
echo "Allowing Wireless access for Non-Admins..."
sed -i 's/auth_admin_keep/yes/g' /usr/share/polkit-1/actions/org.freedesktop.NetworkManager.policy

echo
echo "Enabling Guest Autologin..."
#   autologin-guest=true
#   autologin-user=
#   user-session=LXDE
if [ `grep -c autologin-guest /etc/lightdm/lightdm.conf` -eq "0" ]
then
   echo "autologin-guest=true" >> /etc/lightdm/lightdm.conf
else
   sed -i 's/autologin-guest=false/autologin-guest=true/' /etc/lightdm/lightdm.conf
fi
sed -i 's/autologin-user=.*/autologin-user=/' /etc/lightdm/lightdm.conf
sed -i 's/user-session=ubuntu/user-session=LXDE/' /etc/lightdm/lightdm.conf

echo
echo "Enabling check-for-updates.sh script..."
$RSYNC $SERVER::training-desktops/check-for-updates.sh /opt/
$RSYNC $SERVER::training-desktops/fork.sh /opt/
if [ `grep -c display-setup-script /etc/lightdm/lightdm.conf` -eq "0" ]
then
   echo "display-setup-script=/opt/fork.sh" >> /etc/lightdm/lightdm.conf
fi

echo
echo "Enabling TCPKeepAlive to check for dropped rdesktop connections..."
if [ `grep -c tcp_keepalive /etc/sysctl.conf` -eq "0" ]
then
cat >> /etc/sysctl.conf << EOF1

# tcp_keepalive_time: time in seconds to wait before sending the first keepalive probe (default 7200 seconds).
# tcp_keepalive_intvl: time in seconds for resending probes after the first probe (default 75 seconds).
# tcp_keepalive_probes: if no ACK response is received after this number of probes, connection is marked as broken (default 9 failures).
# You can view or immediately change the current value at /proc/sys/net/ipv4/tcp_keepalive_time
net.ipv4.tcp_keepalive_time = 15
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 4
EOF1
fi

echo
echo "Launching rdesktop script when Guest logs in..."
mkdir --parents /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/guest.desktop << EOF2 
[Desktop Entry]
Type=Application
Exec=/opt/rdesktop.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF2

echo
echo "Changing Guest Desktop Settings..."
#   wallpaper_mode=0
mkdir --parents /etc/skel/.config/pcmanfm/LXDE
$RSYNC $SERVER::training-desktops/pcmanfm.conf /etc/skel/.config/pcmanfm/LXDE/ | grep 'f\.\.T' || touch /tmp/reboot

echo
echo "Changing Guest Screensaver Settings..."
#   mode:       blank
#   timeout:    0:30:00
$RSYNC $SERVER::training-desktops/.xscreensaver /etc/skel/ | grep 'f\.\.T' || touch /tmp/reboot
# View Power Saving settings with: xset q
# The following command changes the Standby, Suspend, and Off values:
xset dpms 3600 0 0
xset q
#gsettings set org.gnome.desktop.session idle-delay 3600
#gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
#gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
if [ `grep -c xset /etc/xdg/lxsession/LXDE/autostart` -eq "0" ]
then
   echo "@xset dpms 7200 0 0" >> /etc/xdg/lxsession/LXDE/autostart
   #echo "@xset s noblank" >> /etc/xdg/lxsession/LXDE/autostart
   #echo "@xset s off" >> /etc/xdg/lxsession/LXDE/autostart
   #echo "@xset -dpms" >> /etc/xdg/lxsession/LXDE/autostart
fi

echo
echo "Changing Guest Bottom Panel Settings..."
#   autohide=1
#   transparent=1
#   background=0
#   width=0
mkdir --parents /etc/skel/.config/lxpanel/LXDE/panels
$RSYNC $SERVER::training-desktops/panel /etc/skel/.config/lxpanel/LXDE/panels/ | grep 'f\.\.T' || touch /tmp/reboot

echo
echo "Changing Guest Session Warning..."
touch /etc/skel/.skip-guest-warning-dialog

echo 
echo "Disabling unused services..."
/usr/sbin/update-rc.d -f atd remove
/usr/sbin/update-rc.d -f smartmontools remove
/usr/sbin/update-rc.d -f rsync remove
/usr/sbin/update-rc.d -f whoopsie remove
/usr/sbin/update-rc.d -f saned remove
/usr/sbin/update-rc.d -f bluetooth remove
/usr/sbin/update-rc.d -f cups remove
/usr/sbin/update-rc.d -f cups-browsed remove
/usr/sbin/update-rc.d -f speech-dispatcher remove
/usr/sbin/update-rc.d -f apport remove
/usr/sbin/update-rc.d -f cgproxy remove
/usr/sbin/update-rc.d -f cgmanager remove
/usr/sbin/update-rc.d -f kerneloops remove

echo
echo "Changing Grub settings..."
if [ `grep -c "GRUB_HIDDEN_TIMEOUT=0" /etc/default/grub` -eq "1" ]
then
   sed -i 's/GRUB_HIDDEN_TIMEOUT=0/GRUB_HIDDEN_TIMEOUT=3/' /etc/default/grub
   /usr/sbin/update-grub
fi

if [ -e /tmp/reboot ]
then
  echo
  echo "Updated files require restart... Rebooting..."
  /sbin/init 6
  exit 0
fi

echo
echo "check-for-updates.sh script finished"

exit 0

