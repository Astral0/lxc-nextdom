#!/bin/bash

# MotionEye script for Debian

set -e

arg1=$1
arg2=$2


#if [ "x${arg1}" == "xwith-mqtt" ]; then
#  USE_MQTT=1
#else
#  USE_MQTT=0
#fi


DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo " >>>> Installation de MotionEye <<<<"


# Install prerequisites
apt update
apt upgrade -y
apt install -y ffmpeg v4l-utils curl wget

# Prerequisites for .deb file
apt install -y libmicrohttpd12 libavcodec58 libavdevice58 libavformat58 libavutil56 libc6 libjpeg62-turbo libmariadb3 libpq5 libsqlite3-0 libssl1.1 libswscale5 zlib1g adduser


# Test if Debian is Buster
distro=buster
. /etc/os-release
if [ ! "x${VERSION_CODENAME}" == "x${distro}" ]; then
    echo "Tested only on Buster. Exiting..."
    exit 1
fi

# Download latest Motion binary
dist=$(uname -m)
if [ ! "${dist}" == "x86_64" ] && [ ! "${dist}" == "armv7l" ] && [ ! "${dist}" == "arm64" ] && [ ! "${dist}" == "armv6l" ] ; then
    echo "Error! Wrong plateform. Exiting..."
    exit 1
fi
if [ "${dist}" == "x86_64" ]; then dist="amd64" ; fi

url=$(curl -s https://api.github.com/repos/Motion-Project/motion/releases/latest |grep ${distro} | grep browser_download_url | grep ${dist} | awk -F": " '{print $2}')

pkgname=$(curl -s https://api.github.com/repos/Motion-Project/motion/releases/latest |grep ${distro} | grep \"name\"\: | grep ${dist} | awk -F": " '{print $2}' | awk -F"\"" '{print $2}')

wget ${url:1:-1}

dpkg -i ${pkgname}

#apt install -y motion

apt install -y python-pip python-dev python-setuptools curl libssl-dev libcurl4-openssl-dev libjpeg-dev libz-dev

# Install MotionEye
pip install motioneye

# Configuration
mkdir -p /etc/motioneye
cp /usr/local/share/motioneye/extra/motioneye.conf.sample /etc/motioneye/motioneye.conf

# Prepare the media directory
mkdir -p /var/lib/motioneye


if [[ -e "/run/systemd/system" ]]; then
  # Enable the systemd service
  cp /usr/local/share/motioneye/extra/motioneye.systemd-unit-local /etc/systemd/system/motioneye.service
  systemctl daemon-reload
  systemctl enable motioneye
  systemctl start motioneye
  systemctl enable motioneye.service
else
  # Enable the sysvinit service
  cp /usr/local/share/motioneye/extra/motioneye.init-debian /etc/init.d/motioneye
  chmod +x /etc/init.d/motioneye
  update-rc.d -f motioneye defaults
  /etc/init.d/motioneye start
fi


# Generate a self-signed Certificat for Nginx
apt install -y openssl
mkdir -p /home/ssl/
cd /home/ssl/
openssl genrsa -out motioneye.key 2048
openssl req -new -key motioneye.key -out motioneye.csr -subj "/C=FR/ST=Paris/L=Paris/O=Global Security/OU=IT Department/CN=example.com"
openssl x509 -req -days 3650 -in motioneye.csr -signkey motioneye.key -out motioneye.crt
#
echo " "
echo ">>> Self-signed SSL Certificate created in /home/ssl/        <<<"
echo ">>> Please feel free to use your own Certificate in :        <<<"
echo ">>> $0"
echo " "

# Security
apt install -y nginx

mkdir -p /var/log/nginx/motioneye/

cat << EOF > /etc/nginx/sites-enabled/motioneye
server {
        listen   443 ssl;
        #server_name     eye.mydomain.com;

        # self signed certificate
        ssl_certificate /home/ssl/motioneye.crt;
        ssl_certificate_key /home/ssl/motioneye.key;

        access_log      /var/log/nginx/motioneye/access.log;
        error_log       /var/log/nginx/motioneye/error.log;
        location / {
                proxy_pass          http://127.0.0.1:8765/;
                proxy_http_version 1.1;
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_read_timeout 43200000;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header Host \$http_host;
                proxy_set_header X-NginX-Proxy true;

# If you want to password protect MotionEye web access, please create htpass file :
#  mkdir -p /home/htpass/
#  htpass -c /home/htpass/.htpasswd my-user-name
# and uncomment next 2 lines :
#                auth_basic "Restricted";                      #For Basic Auth
#                auth_basic_user_file /home/htpass/.htpasswd;  #For Basic Auth

        }
}
EOF

nginx -t

service nginx restart


# Install MQTT
apt install -y mosquitto-clients

echo "
To use MQTT motion trigger, you can use these command in MotionEye :
mosquitto_pub -h my.mqtt.addr -p 1883 -u User -P Password -t cctv/front_door/motion -m "ON" --insecure
"

# Show IP
ip=$(hostname -I)
echo " >>>>  Please open https://${ip} (login=admin, pass empty) <<<<"


