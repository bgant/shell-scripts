#!/bin/bash
#
# 2015-10-26 Brandon Gant
# https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-4-on-ubuntu-14-04
#
# Installs logstash-forwarder to send logs to <Your_Server>
# (it is safe to run this script multiple times on same server)

function old_chroot {
      CHECK=`grep --only-matching "#chroot --userspec" /etc/init.d/logstash-forwarder`
      if [ -z "$CHECK" ]
      then
         echo "Editing chroot command in init.d script..."
         sed -i "s/chroot --userspec/#chroot --userspec/g" /etc/init.d/logstash-forwarder
         sed -i '/#chroot --userspec/a   chroot "$chroot" sh -c "' /etc/init.d/logstash-forwarder
      else
         echo "The init.d script is already configured... Skipping"
      fi
}

case `head --lines=1 /etc/issue` in
'Ubuntu'*)
   echo "I am Debian based Linux... "
   #rm logstash-forwarder.*.centos

   echo "Adding logstash-forwarder to apt-get sources.list..."
   echo 'deb http://packages.elastic.co/logstashforwarder/debian stable main' | tee /etc/apt/sources.list.d/logstashforwarder.list
   
   echo -n "Adding GPG Key for packages... "
   wget -qO - http://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add -
   
   echo "Installing logstash-forwarder package..."
   apt-get -qq update
   apt-get -y install logstash-forwarder

   case `head --lines=1 /etc/issue` in
   'Ubuntu 10.04'*)
      old_chroot
   ;;
   esac
   
   echo "Setting up SSL key for <Your_Server> server..."
   mkdir -p /etc/pki/tls/certs
   cp -v logstash-forwarder.crt /etc/pki/tls/certs/
   
   echo "Configuring logstash-forwarder.conf..."
   cp /etc/logstash-forwarder.conf /etc/logstash-forwarder.conf.orig
   cp -v logstash-forwarder.conf.ubuntu /etc/logstash-forwarder.conf
   
   service logstash-forwarder restart
   service logstash-forwarder status
   #rm logstash-forwarder.sh
;;

'Red Hat'*|'CentOS'*)
   echo -n "I am Red Hat based Linux... "

   case `head --lines=1 /etc/issue` in
   *'release 5'*)
      echo "CentOS 5.x"
      wget https://download.elastic.co/logstash-forwarder/binaries/logstash-forwarder-0.4.0-1.x86_64.rpm
      rpm -i logstash-forwarder-0.4.0-1.x86_64.rpm
      #rm logstash-forwarder-0.4.0-1.x86_64.rpm
  
      old_chroot

      #rm logstash-forwarder.repo.centos
   ;;
   *'release 6'*)
      echo "CentOS 6.x"
      echo "Adding logstash-forwarder to /etc/yum.repos.d/..."
      rpm --import http://packages.elastic.co/GPG-KEY-elasticsearch
      mv -v logstash-forwarder.repo.centos /etc/yum.repos.d/logstash-forwarder.repo
      
      echo "Installing logstash-forwarder package..."
      yum -y install logstash-forwarder
   ;;
   *'release 7'*)
      echo "CentOS 7.x"
      echo "Not tested on this version... Exiting"
      exit 0
   ;;
   *)
      head --lines=1 /etc/issue
      echo "Not tested on this version... Exiting"
      exit 0
   ;;
   esac

   #rm logstash-forwarder.*.ubuntu

   echo "Setting up SSL key for <Your_Server> server..."
   cp -v logstash-forwarder.crt /etc/pki/tls/certs/

   echo "Configuring logstash-forwarder.conf..."
   cp /etc/logstash-forwarder.conf /etc/logstash-forwarder.conf.orig
   cp -v logstash-forwarder.conf.centos /etc/logstash-forwarder.conf

   /sbin/service logstash-forwarder restart
   /sbin/chkconfig logstash-forwarder on
   /sbin/chkconfig --list | grep logstash-forwarder
   /sbin/service logstash-forwarder status
   #rm logstash-forwarder.sh

;;

*)
   echo "I don't know what operating system this is: `head --lines=1 /etc/issue`"
;;
esac

exit 0
