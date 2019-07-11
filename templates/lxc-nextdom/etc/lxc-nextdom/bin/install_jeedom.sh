#!/bin/bash

arg=$1

# Prerequis
apt update
apt -y upgrade
apt install -y software-properties-common gnupg wget hostname
add-apt-repository non-free

# Jeedom
cd /tmp/
wget https://raw.githubusercontent.com/jeedom/core/master/install/install.sh
chmod +x install.sh

# Hack : fail2ban doesn'k work inside LXC container
sed -i 's/fail2ban//g' /tmp/install.sh

# Install Jeedom
./install.sh

# Restore backup
backupfile=
if [ -d "/tmp/backup" ] ; then
    if [ -z ${backupfile} ] ; then
        backupfile=$(ls -atr /tmp/backup/backup* 2>/dev/null | tail -1) >/dev/null 2>/dev/null
    fi
fi
#
if [ ! -z ${backupfile} ] ; then
    if [ -f ${backupfile} ] ; then
        mkdir -p /var/www/html/backup/
        mv ${backupfile} /var/www/html/backup/
        sudo -u www-data php /var/www/html/install/restore.php
    fi
fi

# Show IP
ip=$(hostname -I)
echo " >>>>  Please open http://${ip} <<<<"
