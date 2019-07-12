#!/bin/bash

#arg1=$1
#arg2=$2

echo " >>>> Installation de MotionEye <<<<"

# Install Grafana
apt update
apt upgrade -y

# Install prerequisites
apt install -y motion ffmpeg v4l-utils
apt install -y python-pip python-dev python-setuptools curl libssl-dev libcurl4-openssl-dev libjpeg-dev libz-dev

# Install MotionEye
pip install motioneye

# Configuration
mkdir -p /etc/motioneye
cp /usr/local/share/motioneye/extra/motioneye.conf.sample /etc/motioneye/motioneye.conf

# Prepare the media directory
mkdir -p /var/lib/motioneye

# Start server
cp /usr/local/share/motioneye/extra/motioneye.systemd-unit-local /etc/systemd/system/motioneye.service
systemctl daemon-reload
systemctl enable motioneye
systemctl start motioneye

# Enable the systemd service
systemctl enable motioneye.service

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



# Show IP
ip=$(hostname -I)
echo " >>>>  Please open https://${ip} (login=admin, pass=admin) <<<<"


