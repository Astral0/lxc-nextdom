#!/bin/bash

# voir : https://github.com/krishnasrinivas/wetty

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

#arg1=$1
#arg2=$2

echo " >>>> Installation de Wetty <<<<"

# Create unprivileged user
adduser --disabled-password --gecos "" wettyuser


# Install Prerequisites
apt update
apt upgrade -y
apt install npm node.js git sudo
#apt install node

ln -s /usr/bin/nodejs /usr/bin/node


# Install Wetty
#su - wettyuser
cd /home/wettyuser/
git clone https://github.com/krishnasrinivas/wetty
chown -R wettyuser:wettyuser wetty/
cd wetty/
sudo -u wettyuser 'npm install'


# SSL
mkdir -p /home/ssl/
cd /home/ssl/
openssl genrsa -out motioneye.key 2048
openssl req -new -key motioneye.key -out motioneye.csr -subj "/C=FR/ST=Paris/L=Paris/O=Global Security/OU=IT Department/CN=example.com"
openssl x509 -req -days 3650 -in motioneye.csr -signkey motioneye.key -out motioneye.crt

sudo -u wettyuser 'node /home/wettyuser/wetty/app.js --sslkey /home/ssl/key.pem --sslcert /home/ssl/cert.pem -p 3000' &


# Show IP
ip=$(hostname -I)
echo " >>>>  Please open http://${ip} <<<<"


