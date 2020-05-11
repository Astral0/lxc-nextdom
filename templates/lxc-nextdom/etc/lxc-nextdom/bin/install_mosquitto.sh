#!/bin/bash

# Mosquitto script for Debian

set -e

#arg1=$1
#arg2=$2


# parameters
MQTT_USER=
MQTT_PASS=

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo " >>>> Installation de Mosquitto MQTT broker <<<<"

# Prerequisites
apt update
apt upgrade -y
apt install -y whiptail


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


# Setup login and password
if [ -z ${MQTT_USER} ] ; then
    MQTT_USER=$(whiptail --title "Input" --inputbox "MQTT User" 10 60 user 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_USER=user ; fi
fi

if [ -z ${MQTT_PASS} ] ; then
    pass=$(date +”%N” | md5sum | head -c 8 ; echo)
    MQTT_PASS=$(whiptail --title "Input" --passwordbox "MQTT Password" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then MQTT_PASS=${pass} ; fi

    if [ -z $MQTT_PASS ]; then
        MQTT_PASS=${pass}
    fi
fi


# Prerequisites
apt install -y software-properties-common gnupg wget ca-certificates hostname whiptail apt-transport-https


# Install
wget -O - http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | apt-key add -

if [ -d /etc/apt/sources.list.d ]; then 
    APT_DIR=/etc/apt/sources.list.d 
elif [ -d /etc/apt//etc/apt/sources/list.d ]; then
    APT_DIR=/etc/apt//etc/apt/sources/list.d
else
    echo "Error!"
    exit 1
fi

source /etc/os-release
test $VERSION_ID = "7" && wget -O ${APT_DIR}/mosquitto-wheezy.list http://repo.mosquitto.org/debian/mosquitto-wheezy.list
test $VERSION_ID = "8" && wget -O ${APT_DIR}/mosquitto-jessie.list http://repo.mosquitto.org/debian/mosquitto-jessie.list
test $VERSION_ID = "9" && wget -O ${APT_DIR}/mosquitto-stretch.list http://repo.mosquitto.org/debian/mosquitto-stretch.list
test $VERSION_ID = "10" && wget -O ${APT_DIR}/mosquitto-buster.list http://repo.mosquitto.org/debian/mosquitto-buster.list

apt update
apt install -y mosquitto


# Generate a password for Mosquitto
passfile="/etc/mosquitto/passwordfile"
touch ${passfile}
mosquitto_passwd -b ${passfile} ${MQTT_USER} ${MQTT_USER}

touch /root/mosquitto_passwd
chmod 600 /root/mosquitto_passwd
echo "${MQTT_USER} ${MQTT_PASS}" >>/root/mosquitto_passwd


cat <<EOF >> /etc/mosquitto/mosquitto.conf
allow_anonymous false
password_file ${passfile}
EOF


# Configuration
cat <<EOF > /etc/mosquitto/conf.d/websocket.conf
listener 1883
listener 1884
protocol websockets
EOF


# Start server
systemctl daemon-reload
systemctl start mosquitto
#systemctl status mosquitto

# Enable the systemd service
systemctl enable mosquitto.service

# Restart
service mosquitto restart


# Show IP
ip=$(hostname -I)
echo " >>>>  Please open http://${ip} <<<<"
echo " >>>> Mosquitto user/pass is : ${MQTT_USER}/${MQTT_PASS} ! You can change it in file : ${passfile} <<<<"
