#!/bin/bash

# Zoneminder + Reco script for Debian

set -e

#arg1=$1
#arg2=$2

echo " >>>> Installation de Zoneminder <<<<"

# parameters
MQTT_IP=
MQTT_PORT=
MQTT_USER=
MQTT_PASS=


# Test RAM
#i=$(cat /proc/meminfo |grep MemTotal | awk -F" " '{print $2}')
#ii=$(($i + 0))
#if [ $i -lt 4000000 ]; then echo
#    echo "Less than 4 Go of RAM, switching compilation to 1 core."
#    export CFLAGS="-j1"
#    export CPPFLAGS="-j1"
#    export CXXFLAGS="-j1"
#fi


# Prerequisites
apt update
apt install -y whiptail nmap


# Check TERM
if [ -z ${TERM} ] ; then
    export TERM=ansi
else
    set +e
    isscreen=$(echo $TERM | grep "screen")
    if [ ! -z ${isscreen} ] ; then
        export TERM=ansi
    fi
    set -e
fi
#echo $TERM
#export TERM=vt100

# MQTT
if (whiptail --title "Use MQTT connector ?" --yesno "Use a MQTT Broker ?" 10 60 3>&1 1>&2 2>&3) then
    USE_MQTT=1
else
    USE_MQTT=0
fi
#exitstatus=$? && if [ ! $exitstatus = 0 ]; then USE_MQTT=0 ; fi

if [ "x${USE_MQTT}" == "x1" ]; then

    # Try to detect MQTT server IP or ask this IP
    set +e
    listip=
    if [ -z ${MQTT_IP} ] ; then
        #ll=$(hostname -I | cut -d' ' -f1 | awk -F'.' '{ print $1"."$2"."$3".0/24" }' 2>/dev/null)
        ll=$(hostname -I | cut -d' ' -f1 | awk -F'.' '{ print $1"."$2"."$3"." }' 2>/dev/null)
        lll="${ll}0/24"
        listip=$(nmap --open -p 1883,1884 ${lll} -oG - | grep "/open" | awk '{ print $2 }' | tr '\n' ' ' 2>/dev/null)
            if [ -z ${listip} ] ; then
                first=${ll}
                MQTT_IP=$(whiptail --title "Input" --inputbox "MQTT Server IP" 10 60 $first 3>&1 1>&2 2>&3)
                exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_IP= ; fi
            else
                first=$(echo $listip | cut -d' ' -f1)
                MQTT_IP=$(whiptail --title "Input" --inputbox "MQTT Server IP (detected = ${listip})" 10 60 $first 3>&1 1>&2 2>&3)
                exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_IP= ; fi
            fi
    fi
    set -e


    # # Ask MQTT port
    # if [ -z ${MQTT_PORT} ] ; then
        # MQTT_PORT=$(whiptail --title "Input" --inputbox "MQTT Port" 10 60 1883 3>&1 1>&2 2>&3)
        # exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_PORT= ; fi
    # fi

    # Ask MQTT login and password
    if [ -z ${MQTT_USER} ] ; then
        MQTT_USER=$(whiptail --title "Input" --inputbox "MQTT User" 10 60 user 3>&1 1>&2 2>&3)
        exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_USER= ; fi
    fi

    if [ -z ${MQTT_PASS} ] ; then
        MQTT_PASS=$(whiptail --title "Input" --passwordbox "MQTT Password" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_PASS= ; fi

        if [ -z $MQTT_PASS ]; then
            MQTT_PASS=${pass}
        fi
    fi

    # if [ -z ${MQTT_IP} ] || [ -z ${MQTT_PORT} ] || [ -z ${MQTT_USER} ] || [ -z ${MQTT_PASS} ] ; then
        # echo "<F> Error ! Missing parameters MQTT_IP, MQTT_PORT, MQTT_USER  or MQTT_PASS !"
        # exit 1
    # fi


    if [ -z ${MQTT_IP} ] || [ -z ${MQTT_USER} ] || [ -z ${MQTT_PASS} ] ; then
        echo "<F> Error ! Missing parameters MQTT_IP (-m), MQTT_USER (-u) or MQTT_PASS (-v) !"
        exit 1
    fi

fi


# Install Zoneminder
apt update
apt upgrade -y

# Install prerequisites
apt install -y software-properties-common gnupg wget ca-certificates apt-transport-https sudo git
apt install -y apache2
apt install -y libx11-dev


# Install Zoneminder
wget -O -  https://zmrepo.zoneminder.com/debian/archive-keyring.gpg  | sudo apt-key add -

source /etc/os-release
test $VERSION_ID = "7" && echo "deb  https://zmrepo.zoneminder.com/debian/master  wheezy/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "8" && echo "deb  https://zmrepo.zoneminder.com/debian/master  jessie/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "9" && echo "deb  https://zmrepo.zoneminder.com/debian/master  stretch/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "10" && echo "deb  https://zmrepo.zoneminder.com/debian/master  buster/" >/etc/apt/sources.list.d/zm.list
apt update

apt -y install zoneminder

# Enable the systemd service
systemctl enable zoneminder.service

a2enconf zoneminder
a2enmod rewrite
a2enmod cgi

# PHP path
php_path=$(php --ini | head -n 1 | sed -E "s/.*Path: (.*)\/cli/\\1/")
php_ini="${php_path}/apache2/php.ini"
if [ ! -f ${php_ini} ] ; then
    echo "<F> Error : can't get php.ini file !"
	exit 1
fi
sed -i 's#^.*date.timezone =.*$#date.timezone = Europe/Paris#g' ${php_ini}

# Restart server
service apache2 reload
systemctl daemon-reload
systemctl restart zoneminder

# Generate a self-signed Certificat for Nginx
apt install -y openssl
mkdir -p /etc/zm/apache2/ssl/
cd /etc/zm/apache2/ssl/
openssl genrsa -out zoneminder.key 2048
openssl req -new -key zoneminder.key -out zoneminder.csr -subj "/C=FR/ST=Paris/L=Paris/O=Global Security/OU=IT Department/CN=example.com"
openssl x509 -req -days 3650 -in zoneminder.csr -signkey zoneminder.key -out zoneminder.crt
#
echo " "
echo ">>> Self-signed SSL Certificate created in /etc/zm/apache2/ssl/  <<<"
echo ">>> Please feel free to use your own Certificate                 <<<"
echo " "

chmod o+r /etc/zm/apache2/ssl/zoneminder.key

a2enmod ssl
a2ensite default-ssl
systemctl reload apache2

# For deactivate HTTP access, uncomment below :
#a2dissite 000-default

#zmdc.pl start zmeventnotification.pl

adduser www-data video

# Add service script
cat << \EOF > /etc/init.d/zmeventnotification

#!/bin/bash

### BEGIN INIT INFO
# Provides: zmeventnotification
# Required-Start: $local_fs $syslog $remote_fs
# Required-Stop: $local_fs $syslog $remote_fs
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: ZM Daemon
# Description: zmeventnotification
### END INIT INFO
#/*
# * This file is part of the NextDom software (https://github.com/NextDom or http://nextdom.github.io).
# * Copyright (c) 2018 NextDom - Slobberbone.
# *
# * This program is free software: you can redistribute it and/or modify
# * it under the terms of the GNU General Public License as published by
# * the Free Software Foundation, version 2.
# *
# * This program is distributed in the hope that it will be useful, but
# * WITHOUT ANY WARRANTY; without even the implied warranty of
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# * General Public License for more details.
# *
# * You should have received a copy of the GNU General Public License
# * along with this program. If not, see <http://www.gnu.org/licenses/>.
# */
case "$1" in
    start)
        echo "Starting ZM Daemon for zmeventnotification..."
            sudo -u www-data /usr/bin/zmeventnotification.pl --config /etc/zm/zmeventnotification.ini
            echo $! > /run/zmeventnotification.pid
            ;;
    stop)
            echo "Stopping ZM Daemon for zmeventnotification..."
            kill -9 `cat /run/zmeventnotification.pid`
            rm /run/zmeventnotification.pid
            ;;
    restart)
            $0 stop
            sleep 1
            $0 start
            ;;
    *)
            echo "Usage: $0 {start|stop|restart}"
            exit 1
            ;;
esac
EOF

#mkdir -p /var/log/var/log/zmeventnotification/
#chmod 755 /etc/init.d/zmeventnotification
#systemctl daemon-reload
#systemctl enable zmeventnotification
#systemctl start zmeventnotification


#cat << \EOF > /etc/logrotate.conf
#/var/log/var/log/zmeventnotification/zmeventnotification.log {
#    missingok
#    monthly
#    rotate 1
#}
#EOF




# Installation of ZM Event Notification
# -------------------------------------
cd /usr/bin/
if [ ! -d "/usr/bin/zmeventnotification/" ] ; then
    git clone  https://github.com/pliablepixels/zmeventnotification.git
    cd /usr/bin/zmeventnotification/
else
    cd /usr/bin/zmeventnotification/
    git pull  https://github.com/pliablepixels/zmeventnotification.git
fi


# Change port
sed -i 's/^.*port =.*/port = 9000/g' zmeventnotification.ini

# Enable MQTT
if [ "x${USE_MQTT}" == "x1" ]; then
    sed -i '/^\[mqtt\]$/,/^\[/ s/^enable =.*/enable = yes/' zmeventnotification.ini
    sed -i "/^\[mqtt\]$/,/^\[/ s/^.*server =.*/server = $MQTT_IP/" zmeventnotification.ini
    sed -i "/^\[mqtt\]$/,/^\[/ s/^.*username =.*/username = $MQTT_USER/" zmeventnotification.ini
    sed -i "/^\[mqtt\]$/,/^\[/ s/^.*password =.*/password = $MQTT_PASS/" zmeventnotification.ini
fi

# Enable SSL
sed -i "/^\[ssl\]$/,/^\[/ s#^.*enable =.*#enable = yes#" zmeventnotification.ini
sed -i "/^\[ssl\]$/,/^\[/ s#^cert =.*#cert = /etc/zm/apache2/ssl/zoneminder.crt#" zmeventnotification.ini
sed -i "/^\[ssl\]$/,/^\[/ s#^key =.*#key = /etc/zm/apache2/ssl/zoneminder.key#" zmeventnotification.ini

# Active debug output
sed -i "/^\[customize\]$/,/^\[/ s#^.*console_logs =.*#console_logs = yes#" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#^.*read_alarm_cause =.*#read_alarm_cause = yes#" zmeventnotification.ini

# Picture URL
url=127.0.0.1
username=admin
password=admin
sed -i "/^\[customize\]$/,/^\[/ s/^.*#picture_url =/picture_url =/" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#yourportal.ddns.net#$url#" zmeventnotification.ini 
sed -i "/^\[customize\]$/,/^\[/ s#^.*picture_portal_username=.*#picture_portal_username=$username#" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#^.*picture_portal_password=.*#picture_portal_password=$password#" zmeventnotification.ini

# Hook
sed -i "/^\[hook\]$/,/^\[/ s#^.*hook_script =.*#hook_script = '/usr/bin/detect_wrapper.sh'#" zmeventnotification.ini
sed -i "/^\[hook\]$/,/^\[/ s#^.*use_hook_description =.*#use_hook_description = yes#" zmeventnotification.ini
sed -i "/^\[hook\]$/,/^\[/ s#^.*hook_pass_image_path =.*#hook_pass_image_path = yes#" zmeventnotification.ini 


# Installation de l'Event Server
# ------------------------------
apt install -y gcc make cmake perl libcrypt-mysql-perl libcrypt-eksblowfish-perl libmodule-build-perl python python3-pip libyaml-perl libjson-perl

export PERL_MM_USE_DEFAULT=1
perl -MCPAN -e "install CPAN"  # need yes
perl -MCPAN -e "install Crypt::MySQL"
perl -MCPAN -e "install Config::IniFiles"sudo perl -MCPAN -e "install Crypt::Eksblowfish::Bcrypt"
perl -MCPAN -e "install Net::WebSocket::Server"
perl -MCPAN -e "install LWP::Protocol::https"
perl -MCPAN -e "install Getopt::Long"
if [ "x${USE_MQTT}" == "x1" ]; then
    perl -MCPAN -e "install Net::MQTT::Simple"
fi


chmod a+x /usr/bin/zmeventnotification/zmeventnotification.pl

cd /usr/bin/zmeventnotification/
#sed -i "s/INTERACTIVE='yes'/INTERACTIVE='no'/g" install.sh
./install.sh --no-interactive --install-es --install-hook --install-config


# Installation de la partie reconnaissance
# ----------------------------------------
apt install -y libopenblas-dev liblapack-dev libblas-dev
pip3 install opencv_contrib_python
pip3 install future
pip3 install numpy
pip3 install requests
pip3 install Shapely
pip3 install imutils

# Limit number of core for compilation
#export MAKEFLAGS="-j1"
#export CMAKE_MAKE_PROGRAM="make -j1"
export TRAVIS=true  # hack for compilation of Dlib : TRAVIS=true ==> use only 2 cores
pip3 install dlib

pip3 install face_recognition

mkdir -p /var/lib/zmeventnotification/images
mkdir -p /var/lib/zmeventnotification/models
mkdir -p /var/lib/zmeventnotification/known_faces

# Si vous souhaitez utiliser YoloV3 (lent, précis)
mkdir -p /var/lib/zmeventnotification/models/
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3.cfg -O /var/lib/zmeventnotification/models/yolov3/yolov3.cfg
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names -O /var/lib/zmeventnotification/models/yolov3/yolov3_classes.txt
wget  https://pjreddie.com/media/files/yolov3.weights -O /var/lib/zmeventnotification/models/yolov3/yolov3.weights

# Si vous souhaitez utiliser TinyYoloV3 (plus rapide, moins précis)
mkdir -p /var/lib/zmeventnotification/models/tinyyolo/
wget  https://pjreddie.com/media/files/yolov3-tiny.weights -O /var/lib/zmeventnotification/models/tinyyolo/yolov3-tiny.weights
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3-tiny.cfg -O /var/lib/zmeventnotification/models/tinyyolo/yolov3-tiny.cfg
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names -O /var/lib/zmeventnotification/models/tinyyolo/yolov3-tiny.txt

# Config
cd /usr/bin/zmeventnotification/
cp hook/objectconfig.ini /etc/zm
chown -R www-data:www-data /var/lib/zmeventnotification/
cp -ax hook/zm_detect.py /usr/bin/

sed -i "/^\[general\]$/,/^\[/ s#portal=.*#portal=https://$url/zm#" /etc/zm/objectconfig.ini 
sed -i "/^\[general\]$/,/^\[/ s#user=.*#user=$username#" /etc/zm/objectconfig.ini 
sed -i "/^\[general\]$/,/^\[/ s#password=.*#password=$password#" /etc/zm/objectconfig.ini 



# Restore Cam1
#set +e
#cat << \EOF > /tmp/zm_cams.sql
#INSERT INTO `Monitors` VALUES (1,'cam1',0,0,'Ffmpeg','Modect',1,NULL,'','',0,0,NULL,1,NULL,'rtpRtsp',NULL,'','','rtsp://viewer:viewer@10.0.0.66:554/Streaming/Channels/101',NULL,NULL,NULL,1920,1080,3,0,'0',0,NULL,NULL,3,0,NULL,NULL,'# Lines beginning with # are a comment \r\n# For changing quality, use the crf option\r\n# 1 is best, 51 is worst quality\r\n#crf=23',0,0,-1,-1,-1,-1,'Event-','%N - %d/%m/%y %H:%M:%S',0,0,1,100,0,0,0,0,1,600,10,0,0,NULL,0,NULL,NULL,100,6,6,0,NULL,NULL,NULL,NULL,0,NULL,-1,NULL,100,100,'auto',0,'#0000BE','red',0,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL);
#EOF
#mysql -u root --database='zm' < /tmp/zm_cams.sql
#rm -f /tmp/zm_cams.sql
#set -e




# Show IP
ip=$(hostname -I)
echo " >>>>  Please open https://${ip}/zm (login=admin, pass=admin) <<<<"


#!/bin/bash

# Zoneminder + Reco script for Debian

set -e

#arg1=$1
#arg2=$2

echo " >>>> Installation de Zoneminder <<<<"

# parameters
MQTT_IP=
MQTT_USER=
MQTT_PASS=


# Prerequisites
apt update
apt install -y whiptail nmap


# Check TERM
if [ -z ${TERM} ] ; then
    export TERM=ansi
else
    set +e
    isscreen=$(echo $TERM | grep "screen")
    if [ ! -z ${isscreen} ] ; then
        export TERM=ansi
    fi
    set -e
fi
#echo $TERM
#export TERM=vt100

# Try to detect MQTT server IP or ask this IP
set +e
listip=
if [ -z ${MQTT_IP} ] ; then
    #ll=$(hostname -I | cut -d' ' -f1 | awk -F'.' '{ print $1"."$2"."$3".0/24" }' 2>/dev/null)
    ll=$(hostname -I | cut -d' ' -f1 | awk -F'.' '{ print $1"."$2"."$3"." }' 2>/dev/null)
	lll="${ll}0/24"
    listip=$(nmap --open -p 1883,1884 ${lll} -oG - | grep "/open" | awk '{ print $2 }' | tr '\n' ' ' 2>/dev/null)
	if [ -z ${listip} ] ; then
	    first=${ll}
		MQTT_IP=$(whiptail --title "Input" --inputbox "MQTT Server IP" 10 60 $first 3>&1 1>&2 2>&3)
		exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_USER= ; fi
	else
        first=$(echo $listip | cut -d' ' -f1)
		MQTT_IP=$(whiptail --title "Input" --inputbox "MQTT Server IP (detected = ${listip})" 10 60 $first 3>&1 1>&2 2>&3)
		exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_USER= ; fi
	fi
fi
set -e

# Ask MQTT login and password
if [ -z ${MQTT_USER} ] ; then
    MQTT_USER=$(whiptail --title "Input" --inputbox "MQTT User" 10 60 user 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_USER= ; fi
fi

if [ -z ${MQTT_PASS} ] ; then
    MQTT_PASS=$(whiptail --title "Input" --passwordbox "MQTT Password" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_PASS= ; fi

    if [ -z $MQTT_PASS ]; then
        MQTT_PASS=${pass}
    fi
fi

if [ -z ${MQTT_IP} ] || [ -z ${MQTT_USER} ] || [ -z ${MQTT_PASS} ] ; then
    echo "<F> Error ! Missing parameters MQTT_IP (-m), MQTT_USER (-u) or MQTT_PASS (-v) !"
	exit 1
fi


# Install Zoneminder
apt update
apt upgrade -y

# Install prerequisites
apt install -y software-properties-common gnupg wget ca-certificates apt-transport-https sudo git
apt install -y apache2


# Install Zoneminder
wget -O -  https://zmrepo.zoneminder.com/debian/archive-keyring.gpg  | sudo apt-key add -

source /etc/os-release
test $VERSION_ID = "7" && echo "deb  https://zmrepo.zoneminder.com/debian/master  wheezy/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "8" && echo "deb  https://zmrepo.zoneminder.com/debian/master  jessie/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "9" && echo "deb  https://zmrepo.zoneminder.com/debian/master  stretch/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "10" && echo "deb  https://zmrepo.zoneminder.com/debian/master  buster/" >/etc/apt/sources.list.d/zm.list
apt update

apt -y install zoneminder

# Enable the systemd service
systemctl enable zoneminder.service

a2enconf zoneminder
a2enmod rewrite
a2enmod cgi

# PHP path
php_path=$(php --ini | head -n 1 | sed -E "s/.*Path: (.*)\/cli/\\1/")
php_ini="${php_path}/apache2/php.ini"
if [ ! -f ${php_ini} ] ; then
    echo "<F> Error : can't get php.ini file !"
	exit 1
fi
sed -i 's#^.*date.timezone =#date.timezone = Europe/Paris#g' ${php_ini}

# Restart server
service apache2 reload
systemctl daemon-reload
systemctl restart zoneminder

# Generate a self-signed Certificat for Nginx
apt install -y openssl
mkdir -p /etc/zm/apache2/ssl/
cd /etc/zm/apache2/ssl/
openssl genrsa -out zoneminder.key 2048
openssl req -new -key zoneminder.key -out zoneminder.csr -subj "/C=FR/ST=Paris/L=Paris/O=Global Security/OU=IT Department/CN=example.com"
openssl x509 -req -days 3650 -in zoneminder.csr -signkey zoneminder.key -out zoneminder.crt
#
echo " "
echo ">>> Self-signed SSL Certificate created in /etc/zm/apache2/ssl/  <<<"
echo ">>> Please feel free to use your own Certificate                 <<<"
echo " "

chmod o+r /etc/zm/apache2/ssl/zoneminder.key

a2enmod ssl
a2ensite default-ssl
systemctl reload apache2

# For deactivate HTTP access, uncomment below :
#a2dissite 000-default

#zmdc.pl start zmeventnotification.pl

adduser www-data video

# Add service script
cat << \EOF > /etc/init.d/zmeventnotification

#!/bin/bash

### BEGIN INIT INFO
# Provides: zmeventnotification
# Required-Start: $local_fs $syslog $remote_fs
# Required-Stop: $local_fs $syslog $remote_fs
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: ZM Daemon 
# Description: zmeventnotification
### END INIT INFO
#/*
# * This file is part of the NextDom software (https://github.com/NextDom or http://nextdom.github.io).
# * Copyright (c) 2018 NextDom - Slobberbone.
# *
# * This program is free software: you can redistribute it and/or modify
# * it under the terms of the GNU General Public License as published by
# * the Free Software Foundation, version 2.
# *
# * This program is distributed in the hope that it will be useful, but
# * WITHOUT ANY WARRANTY; without even the implied warranty of
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# * General Public License for more details.
# *
# * You should have received a copy of the GNU General Public License
# * along with this program. If not, see <http://www.gnu.org/licenses/>.
# */
case "$1" in
    start)
        echo "Starting ZM Daemon for zmeventnotification..."
            sudo -u www-data /usr/bin/zmeventnotification.pl --config /etc/zm/zmeventnotification.ini
            echo $! > /run/zmeventnotification.pid
            ;;
    stop)
            echo "Stopping ZM Daemon for zmeventnotification..."
            kill -9 `cat /run/zmeventnotification.pid`
            rm /run/zmeventnotification.pid
            ;;
    restart)
            $0 stop
            sleep 1
            $0 start
            ;;
    *)
            echo "Usage: $0 {start|stop|restart}"
            exit 1
            ;;
esac
EOF

#mkdir -p /var/log/var/log/zmeventnotification/
#chmod 755 /etc/init.d/zmeventnotification
#systemctl daemon-reload
#systemctl enable zmeventnotification
#systemctl start zmeventnotification


#cat << \EOF > /etc/logrotate.conf
#/var/log/var/log/zmeventnotification/zmeventnotification.log {
#    missingok
#    monthly
#    rotate 1
#}
#EOF




# Installation of ZM Event Notification
# -------------------------------------
cd /usr/bin/
git clone  https://github.com/pliablepixels/zmeventnotification.git 
cd /usr/bin/zmeventnotification/

# Change port
sed -i 's/^.*port =.*/port = 9000/g' zmeventnotification.ini

# Enable MQTT
sed -i '/^\[mqtt\]$/,/^\[/ s/^enable =.*/enable = yes/' zmeventnotification.ini
sed -i "/^\[mqtt\]$/,/^\[/ s/^.*server =.*/server = $MQTT_IP/" zmeventnotification.ini
sed -i "/^\[mqtt\]$/,/^\[/ s/^.*username =.*/username = $MQTT_USER/" zmeventnotification.ini
sed -i "/^\[mqtt\]$/,/^\[/ s/^.*password =.*/password = $MQTT_PASS/" zmeventnotification.ini

# Enable SSL
sed -i "/^\[ssl\]$/,/^\[/ s#^.*enable =.*#enable = yes#" zmeventnotification.ini
sed -i "/^\[ssl\]$/,/^\[/ s#^cert =.*#cert = /etc/zm/apache2/ssl/zoneminder.crt#" zmeventnotification.ini
sed -i "/^\[ssl\]$/,/^\[/ s#^key =.*#key = /etc/zm/apache2/ssl/zoneminder.key#" zmeventnotification.ini

# Active debug output
sed -i "/^\[customize\]$/,/^\[/ s#^.*console_logs =.*#console_logs = yes#" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#^.*read_alarm_cause =.*#read_alarm_cause = yes#" zmeventnotification.ini

# Picture URL
url=127.0.0.1
username=admin
password=admin
sed -i "/^\[customize\]$/,/^\[/ s/^.*#picture_url =/picture_url =/" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#yourportal.ddns.net#$url#" zmeventnotification.ini 
sed -i "/^\[customize\]$/,/^\[/ s#^.*picture_portal_username=.*#picture_portal_username=$username#" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#^.*picture_portal_password=.*#picture_portal_password=$password#" zmeventnotification.ini

# Hook
sed -i "/^\[hook\]$/,/^\[/ s#^.*hook_script =.*#hook_script = '/usr/bin/detect_wrapper.sh'#" zmeventnotification.ini
sed -i "/^\[hook\]$/,/^\[/ s#^.*use_hook_description =.*#use_hook_description = yes#" zmeventnotification.ini
sed -i "/^\[hook\]$/,/^\[/ s#^.*hook_pass_image_path =.*#hook_pass_image_path = yes#" zmeventnotification.ini 


# Installation de l'Event Server
# ------------------------------
apt install -y gcc make cmake perl libcrypt-mysql-perl libcrypt-eksblowfish-perl libmodule-build-perl python python3-pip libyaml-perl libjson-perl

export PERL_MM_USE_DEFAULT=1
perl -MCPAN -e "install CPAN"  # need yes
perl -MCPAN -e "install Crypt::MySQL"
perl -MCPAN -e "install Config::IniFiles"sudo perl -MCPAN -e "install Crypt::Eksblowfish::Bcrypt"
perl -MCPAN -e "install Net::WebSocket::Server"
perl -MCPAN -e "install LWP::Protocol::https"
perl -MCPAN -e "install Net::MQTT::Simple"
perl -MCPAN -e "install Getopt::Long"

chmod a+x /usr/bin/zmeventnotification/zmeventnotification.pl

cd /usr/bin/zmeventnotification/
#sed -i "s/INTERACTIVE='yes'/INTERACTIVE='no'/g" install.sh
./install.sh --no-interactive --install-es --install-hook --install-config


# Installation de la partie reconnaissance
# ----------------------------------------
apt install -y libopenblas-dev liblapack-dev libblas-dev
pip3 install opencv_contrib_python
pip3 install future
pip3 install numpy
pip3 install requests
pip3 install Shapely
pip3 install imutils

#export CFLAGS="-j 1"
#export CPPFLAGS="-j 1"
#export CXXFLAGS="-j 1"

pip3 install face_recognition

mkdir -p /var/lib/zmeventnotification/images
mkdir -p /var/lib/zmeventnotification/models
mkdir -p /var/lib/zmeventnotification/known_faces

# Si vous souhaitez utiliser YoloV3 (lent, précis)
mkdir -p /var/lib/zmeventnotification/models/
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3.cfg -O /var/lib/zmeventnotification/models/yolov3/yolov3.cfg
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names -O /var/lib/zmeventnotification/models/yolov3/yolov3_classes.txt
wget  https://pjreddie.com/media/files/yolov3.weights -O /var/lib/zmeventnotification/models/yolov3/yolov3.weights

# Si vous souhaitez utiliser TinyYoloV3 (plus rapide, moins précis)
mkdir -p /var/lib/zmeventnotification/models/tinyyolo
wget  https://pjreddie.com/media/files/yolov3-tiny.weights -O /var/lib/zmeventnotification/models/tinyyolo/yolov3-tiny.weights
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3-tiny.cfg -O /var/lib/zmeventnotification/models/tinyyolo/yolov3-tiny.cfg
wget  https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names -O /var/lib/zmeventnotification/models/tinyyolo/yolov3-tiny.txt

# Config
cd /usr/bin/zmeventnotification/
cp hook/objectconfig.ini /etc/zm
chown -R www-data:www-data /var/lib/zmeventnotification/
cp -ax hook/detect.py /usr/bin/

sed -i "/^\[general\]$/,/^\[/ s#portal=.*#portal=https://$url/zm#" /etc/zm/objectconfig.ini 
sed -i "/^\[general\]$/,/^\[/ s#user=.*#user=$username#" /etc/zm/objectconfig.ini 
sed -i "/^\[general\]$/,/^\[/ s#password=.*#password=$password#" /etc/zm/objectconfig.ini 



# Restore Cam1
#set +e
#cat << \EOF > /tmp/zm_cams.sql
#INSERT INTO `Monitors` VALUES (1,'cam1',0,0,'Ffmpeg','Modect',1,NULL,'','',0,0,NULL,1,NULL,'rtpRtsp',NULL,'','','rtsp://viewer:viewer@10.0.0.66:554/Streaming/Channels/101',NULL,NULL,NULL,1920,1080,3,0,'0',0,NULL,NULL,3,0,NULL,NULL,'# Lines beginning with # are a comment \r\n# For changing quality, use the crf option\r\n# 1 is best, 51 is worst quality\r\n#crf=23',0,0,-1,-1,-1,-1,'Event-','%N - %d/%m/%y %H:%M:%S',0,0,1,100,0,0,0,0,1,600,10,0,0,NULL,0,NULL,NULL,100,6,6,0,NULL,NULL,NULL,NULL,0,NULL,-1,NULL,100,100,'auto',0,'#0000BE','red',0,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL);
#EOF
#mysql -u root --database='zm' < /tmp/zm_cams.sql
#rm -f /tmp/zm_cams.sql
#set -e




# Show IP
ip=$(hostname -I)
echo " >>>>  Please open https://${ip} (login=admin, pass=admin) <<<<"


