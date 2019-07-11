#!/bin/bash

#arg1=$1
#arg2=$2

echo " >>>> Installation de Grafana <<<<"

# Install Grafana
apt update
apt upgrade -y
apt install -y software-properties-common gnupg wget ca-certificates apt-transport-https hostname
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
apt update
apt install -y grafana

# Start Grafana server
systemctl daemon-reload
systemctl start grafana-server
systemctl status grafana-server

# Enable the systemd service
systemctl enable grafana-server.service

# Show IP
ip=$(hostname -I)
echo " >>>>  Please open http://${ip} (login=admin, pass=admin) <<<<"


