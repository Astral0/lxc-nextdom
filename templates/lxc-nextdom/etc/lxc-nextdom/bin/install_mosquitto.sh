#!/bin/bash

#arg1=$1
#arg2=$2

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo " >>>> Installation de Mosquitto MQTT broker <<<<"

# Install
apt update
apt upgrade -y
apt install -y software-properties-common gnupg wget ca-certificates hostname
wget -O - http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | apt-key add -

source /etc/os-release
test $VERSION_ID = "7" && wget -O /etc/apt/sources/list.d/mosquitto-wheezy.list http://repo.mosquitto.org/debian/mosquitto-wheezy.list
test $VERSION_ID = "8" && wget -O /etc/apt/sources/list.d/mosquitto-jessie.list http://repo.mosquitto.org/debian/mosquitto-jessie.list
test $VERSION_ID = "9" && wget -O /etc/apt/sources/list.d/mosquitto-stretch.list http://repo.mosquitto.org/debian/mosquitto-stretch.list
test $VERSION_ID = "10" && wget -O /etc/apt/sources/list.d/mosquitto-buster.list http://repo.mosquitto.org/debian/mosquitto-buster.list

apt update
apt install -y mosquitto


# Generate a password for Mosquitto
pass=$(date +”%N” | md5sum | head -c 8 ; echo)
passfile="/etc/mosquitto/passwordfile"
touch ${passfile}
mosquitto_passwd -b ${passfile} user ${pass}

touch /root/mosquitto_passwd
chmod 600 /root/mosquitto_passwd
echo "user ${pass}" >>/root/mosquitto_passwd


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
systemctl status mosquitto

# Enable the systemd service
systemctl enable mosquitto.service

# Restart
service mosquitto restart


# Show IP
ip=$(hostname -I)
echo " >>>>  Please open http://${ip} <<<<"
echo " >>>> Mosquitto user/pass is : user/${pass} ! You can change it in file : ${passfile} <<<<"
