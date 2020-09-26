#!/bin/bash
#
# Brandon Gant
# Updated: 2016-12-16
#
# Installs SSH 2-Factor Authentication

function AddUsersFunction {
   echo "Setting up yubikey group..."
   /usr/sbin/groupadd yubikey
   # Need to add awk command to grab first field from "yubikeys" file
   # and run the following command on each field:
   #   /usr/sbin/usermod -a -G yubikey <user1>

   echo "Setting up duo group..."
   /usr/sbin/groupadd duo
}

case `head --lines=1 /etc/issue` in
'Ubuntu'*)
   echo -n "I am Debian based Linux..."

   case `head --lines=1 /etc/issue` in
   'Ubuntu 12.04'*)
      echo "Ubuntu 12.04"
   ;;
   'Ubuntu 14.04'*)
      echo "Ubuntu 14.04"
   ;;
   'Ubuntu 16.04'*)
      echo "Ubuntu 16.04"
   ;;
   *)
      `head --lines=1 /etc/issue`
      echo "This script has not been tested on this version... Exiting"
      exit 0
   ;;
   esac

   echo "Installing packages..."
   apt-get -qq update
   apt-get -y install libpam-yubico libykclient3 libpam_duo

   mv -v yubikeys /etc/
   mv -v pam_duo.conf /etc/security/
   mv -v two-factor-auth.ubuntu /etc/pam.d/two-factor-auth
   
   AddUsersFunction

   echo "Editing /etc/ssh/sshd_config..."
   sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config

   # Add "@include two-factor-auth" to the bottom of /etc/pam.d/sshd on Ubuntu
   CHECK=`grep --only-matching "two-factor-auth" /etc/pam.d/sshd`
   if [ -z "$CHECK" ]
   then
      echo "two-factor-auth is not already in /etc/pam.d/sshd... Adding two-factor-auth..."
      CHECK=`grep --only-matching "yubikey-passwd-auth" /etc/pam.d/sshd`
      if [ -z "$CHECK" ]
      then
         echo >> /etc/pam.d/sshd
         echo '# 2-Factor authentication' >> /etc/pam.d/sshd
         echo '@include two-factor-auth' >> /etc/pam.d/sshd
      else
         echo "yubikey-passwd-auth is in /etc/pam.d/sshd... Replacing with two-factor-auth..."
         sed -i "s/yubikey-passwd-auth/two-factor-auth/g" /etc/pam.d/sshd
         rm -v /etc/pam.d/yubikey-passwd-auth
   else
      echo "two-factor-auth is already in /etc/pam.d/sshd... Skipping..."
   fi

   service ssh restart
   echo "Add users to the yubikey or duo group: sudo usermod -a -G <yubikey|duo> <username>"
   echo "WARNING: Open another terminal and test login before exiting this terminal!"

;;

'Red Hat'*|'CentOS'*)
   echo -n "I am Red Hat based Linux... "

   case `head --lines=1 /etc/issue` in
   *'release 5'*)
      echo "CentOS 5.x"
      mv -v yubikey-passwd-auth.centos5 /etc/pam.d/yubikey-passwd-auth
   ;;
   *'release 6'*)
      echo "CentOS 6.x"
      mv -v yubikey-passwd-auth.centos6 /etc/pam.d/yubikey-passwd-auth
   ;;
   *'release 7'*)
      echo "CentOS 7.x"
      echo "This script has not been tested on CentOS 7.x... Exiting script"
      exit 0
   ;;
   *)
      `head --lines=1 /etc/issue`
      echo "Not tested on this version... Exiting"
      exit 0
   ;;
   esac

   rm yubikey*.ubuntu

   echo "Installing Yubikey package..."
   yum -y install pam_yubico

   mv -v yubikeys /etc/

   AddUsersFunction

   echo "Editing /etc/ssh/sshd_config..."
   sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config

   # Add "auth include two-factor-auth" at the top of /etc/pam.d/sshd on CentOS
   CHECK=`grep --only-matching "yubikey-passwd-auth" /etc/pam.d/sshd`
   if [ -z "$CHECK" ]
   then
      echo "yubikey-passwd-auth is not in /etc/pam.d/sshd... Adding"
      sed -i '2 i auth       include      yubikey-passwd-auth' /etc/pam.d/sshd
   else
      echo "yubikey-passwd-auth is already in /etc/pam.d/sshd... Skipping"
   fi

   /sbin/service sshd restart
   echo "Add users to the yubikey group: sudo usermod -a -G yubikey <user>"
   rm yubikey*.centos*
   rm yubikey-install.sh
   echo "WARNING: Open another terminal and test login before exiting this terminal!"
;;

*)
   echo "I don't know what operating system this is: `head --lines=1 /etc/issue`"
;;
esac

exit 0
