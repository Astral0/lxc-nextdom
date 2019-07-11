#!/bin/bash

arg=$1

# Prerequis
apt update
apt -y upgrade
apt install -y software-properties-common gnupg wget
add-apt-repository non-free
wget -qO -  http://debian.nextdom.org/debian/nextdom.gpg.key  | apt-key add -
echo "deb  http://debian.nextdom.org/debian  nextdom main" >/etc/apt/sources.list.d/nextdom.list
apt update

# Nextdom stable
if [ -z $arg} ] ; then
    apt -y install nextdom

# Nextdom development
else
    apt -y install nextdom-common

    if [[ -d "/var/www/nextdomdev" ]] ; then
        rm -rf /var/www/nextdomdev
        rm -f /var/www/html
    fi
    echo "Clone repos"
    #
    mkdir /var/www/nextdomdev
    cd /var/www/nextdomdev
    #
    git clone https://github.com/NextDom/nextdom-core .
    echo "Change branch"
    git checkout ${arg}
    #
    sudo ./install/postinst

fi

# Restore backup
backupfile=
if [ -d "/var/lib/nextdom/backup" ] ; then
    if [ -z ${backupfile} ] ; then
        backupfile=$(ls -atr /var/lib/nextdom/backup/backup* 2>/dev/null | tail -1) >/dev/null 2>/dev/null
    fi
fi
#
if [ ! -z ${backupfile} ] ; then
    if [ -f ${backupfile} ] ; then
        sudo -u www-data php /var/www/html/install/restore.php
    fi
fi
