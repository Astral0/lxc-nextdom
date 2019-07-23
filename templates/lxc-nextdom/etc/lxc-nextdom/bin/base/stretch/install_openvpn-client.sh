#!/bin/bash

key=$1
server=$2
port=$3


# Check all parameters
if [ -z ${key} ] ; then
    echo "<F> Missing argument 'key' path !"
    exit 1
fi

if [ ! -f "${key}" ] ; then
    echo "<F> Error: file not present : ${key} !"
    exit 1
fi

if [ ! -z ${server} ] ; then
    if [ -z ${port} ] ; then
        echo "<I> Server port not specified, change it to 443"
        port="443"
    fi
    echo "<I> Change server/port address to : ${server} ${port}"
    sed -i "s/^remote .*/remote ${server} ${port}/g" ${key}
fi


# Install openvpn
apt update
apt upgrade -y
apt install openvpn


# Copy key
fn=$(basename ${key})
cp ${key} /etc/openvpn/
cd /etc/openvpn/
ln -s ${fn} client.conf


# Virtual interface
mkdir -p /dev/net
set +e
mknod /dev/net/tun c 10 200
set -e


# Starting and Enabling the OpenVPN Service
systemctl start openvpn@client
systemctl enable openvpn@client

ip addr show tun0

# Show IP
ip=$(hostname -I)
echo " >>>>  OpenVPN IP: ${ip} <<<<"

