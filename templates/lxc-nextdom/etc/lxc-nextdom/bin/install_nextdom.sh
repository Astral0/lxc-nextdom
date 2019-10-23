#!/bin/bash

arg=$1
echo $arg

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

# Prerequis
apt update
apt -y upgrade
apt install -y software-properties-common gnupg wget hostname
add-apt-repository non-free

# Nextdom stable
if [ -z $arg} ] || [ "$arg" == "nextdom" ] ; then
    wget -qO -  http://debian.nextdom.org/debian/nextdom.gpg.key  | apt-key add -
    echo "deb  http://debian.nextdom.org/debian  nextdom main" >/etc/apt/sources.list.d/nextdom.list
    apt update
    #
    apt -y install nextdom

# Nextdom stable on dev repos
elif [ -z $arg} ] || [ "$arg" == "nextdom-dev" ] ; then
    wget -qO -  http://debian-dev.nextdom.org/debian/nextdom.gpg.key  | apt-key add -
    echo "deb  http://debian-dev.nextdom.org/debian  nextdom main" >/etc/apt/sources.list.d/nextdom.list
    apt update
    #
    apt -y install nextdom

# Nextdom nightly
elif [ -z $arg} ] || [ "$arg" == "nextdom-nightly" ] ; then
    wget -qO -  http://debian-nightly.nextdom.org/debian/nextdom.gpg.key  | apt-key add -
    echo "deb  http://debian-nightly.nextdom.org/debian  nextdom main" >/etc/apt/sources.list.d/nextdom.list
    apt update
    #
    apt -y install nextdom

# Nextdom development
else
    wget -qO -  http://debian.nextdom.org/debian/nextdom.gpg.key  | apt-key add -
    echo "deb  http://debian.nextdom.org/debian  nextdom main" >/etc/apt/sources.list.d/nextdom.list
    apt update
    #
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
    bash -x ./install/postinst

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

# Show IP
ip=$(hostname -I)
echo " >>>>  Please open http://${ip} <<<<"
