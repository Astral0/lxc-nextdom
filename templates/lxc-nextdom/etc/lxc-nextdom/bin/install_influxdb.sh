#!/bin/bash

arg1=$1
arg2=$2

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo " >>>> Installation de InfluxDB <<<<"

# Install Influxdb
apt update
apt upgrade -y
apt install -y software-properties-common gnupg wget ca-certificates apt-transport-https hostname
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/os-release
test $VERSION_ID = "7" && echo "deb https://repos.influxdata.com/debian wheezy stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
test $VERSION_ID = "8" && echo "deb https://repos.influxdata.com/debian jessie stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
test $VERSION_ID = "9" && echo "deb https://repos.influxdata.com/debian stretch stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
test $VERSION_ID = "10" && echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
#
apt update
apt install -y influxdb

# Enable the systemd service
systemctl unmask influxdb.service
systemctl start influxdb

# Show IP
ip=$(hostname -I)
echo " >>>>  InfluxDB installed on IP ${ip}  <<<<"
