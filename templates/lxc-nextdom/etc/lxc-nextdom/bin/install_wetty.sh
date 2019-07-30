#!/bin/bash

# voir : https://github.com/krishnasrinivas/wetty

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
su - wettyuser
git clone https://github.com/krishnasrinivas/wetty
cd wetty/
npm install


# SSL
mkdir /home/ssl
cd /home/ssl
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 30000 -nodes

sudo -u wettyuser node /home/wettyuser/wetty/app.js --sslkey /home/ssl/key.pem --sslcert /home/ssl/cert.pem -p 3000 &





# Show IP
ip=$(hostname -I)
echo " >>>>  Please open http://${ip} (login=admin, pass=admin) <<<<"


