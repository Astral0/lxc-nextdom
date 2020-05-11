#!/bin/bash

# OpenVPN Debian 9 version

set -e

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND


arg1=$1
arg2=$2

echo " >>>> Installation de OpenVPN Server <<<<"

# Params
openvpn_root="/root/vpn"
openvpn_ca=${openvpn_root}/openvpn-ca
clients=${openvpn_root}/client-configs
install_files="/root/tmp/install"


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


# Prerequisites
apt update
apt -y upgrade
apt install -y openvpn easy-rsa wget hostname whiptail gzip


# Creation/effacement du repertoire
if [ -f ${openvpn_root} ] || [ -d ${openvpn_root} ] ; then
    if (whiptail --title "${openvpn_root} deja present" --yesno "Effacer ${openvpn_root} ?" 10 60) then
        rm -rf ${openvpn_root}
    fi
fi
mkdir -p ${openvpn_root}




# -------------------------------------------------------------------------------------------
# Copy OpenVPN templates in directory
mkdir -p ${clients}/


cat <<EOF >> ${clients}/base.conf
##############################################
# Sample client-side OpenVPN 2.0 config file #
# for connecting to multi-client server.     #
#                                            #
# This configuration can be used by multiple #
# clients, however each client should have   #
# its own cert and key files.                #
#                                            #
# On Windows, you might want to rename this  #
# file so it has a .ovpn extension           #
##############################################

# Specify that we are a client and that we
# will be pulling certain config file directives
# from the server.
client

# Use the same setting as you are using on
# the server.
# On most systems, the VPN will not function
# unless you partially or fully disable
# the firewall for the TUN/TAP interface.
;dev tap
dev tun

# Windows needs the TAP-Win32 adapter name
# from the Network Connections panel
# if you have more than one.  On XP SP2,
# you may need to disable the firewall
# for the TAP adapter.
;dev-node MyTap

# Are we connecting to a TCP or
# UDP server?  Use the same setting as
# on the server.
proto tcp
;proto udp

# The hostname/IP and port of the server.
# You can have multiple remote entries
# to load balance between the servers.
remote 10.0.0.119 8443
;remote my-server-2 1194

# Choose a random host from the remote
# list for load-balancing.  Otherwise
# try hosts in the order specified.
;remote-random

# Keep trying indefinitely to resolve the
# host name of the OpenVPN server.  Very useful
# on machines which are not permanently connected
# to the internet such as laptops.
resolv-retry infinite

# Most clients don't need to bind to
# a specific local port number.
nobind

# Downgrade privileges after initialization (non-Windows only)
;user nobody
;group nogroup

# Try to preserve some state across restarts.
persist-key
persist-tun

# If you are connecting through an
# HTTP proxy to reach the actual OpenVPN
# server, put the proxy server/IP and
# port number here.  See the man page
# if your proxy server requires
# authentication.
;http-proxy-retry # retry on connection failures
;http-proxy [proxy server] [proxy port #]

# Wireless networks often produce a lot
# of duplicate packets.  Set this flag
# to silence duplicate packet warnings.
;mute-replay-warnings

# SSL/TLS parms.
# See the server config file for more
# description.  It's best to use
# a separate .crt/.key file pair
# for each client.  A single ca
# file can be used for all clients.
ca ca.crt
cert client.crt
key client.key

# Verify server certificate by checking that the
# certicate has the correct key usage set.
# This is an important precaution to protect against
# a potential attack discussed here:
#  http://openvpn.net/howto.html#mitm
#
# To use this feature, you will need to generate
# your server certificates with the keyUsage set to
#   digitalSignature, keyEncipherment
# and the extendedKeyUsage to
#   serverAuth
# EasyRSA can do this for you.
remote-cert-tls server

# If a tls-auth key is used on the server
# then every client must also have the key.
tls-auth ta.key 1

# Select a cryptographic cipher.
# If the cipher option is used on the server
# then you must also specify it here.
# Note that 2.4 client/server will automatically
# negotiate AES-256-GCM in TLS mode.
# See also the ncp-cipher option in the manpage
cipher AES-256-CBC
auth SHA256

# Enable compression on the VPN link.
# Don't enable this unless it is also
# enabled in the server config file.
#comp-lzo

# Set log file verbosity.
verb 3

# Silence repeating messages
;mute 20
EOF



# -------------------------------------------------------------------------------------------
# 
cat <<EOF >> ${openvpn_root}/make-client-config.sh
#!/bin/bash

# First argument: Client identifier

if [ "x$1" == "x" ]
then
  echo Need an argument
  exit 1
fi

# Params
openvpn_root="/root/vpn"
openvpn_ca=${openvpn_root}/openvpn-ca
clients=${openvpn_root}/client-configs
install_files="/root/install_files"

# Tests
if [ ! -d ${openvpn_ca} ] ; then
    echo "Error ! Directory Server Certificates are not present!"
    exit 1
fi
#
mkdir -p ${clients}
if [ ! -f "${clients}/base.conf" ] ; then
    if [ -f "${install_files}/base.conf" ] ; then
        cp -ax ${install_files}/base.conf ${clients}/base.conf
    else
        echo "Error ! Missing base.conf files !"
    fi
fi

# Generate client key
cd ${openvpn_ca}
source vars
#./build-key ${1}
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" ${1}


KEY_DIR=${openvpn_ca}/keys
OUTPUT_DIR=${clients}/files
BASE_CONFIG=${clients}/base.conf
mkdir -p ${OUTPUT_DIR}

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}.ovpn

echo "Client key written : ${OUTPUT_DIR}/${1}.ovpn"
EOF
chmod 755 ${openvpn_root}/make-client-config.sh


# Create easy-rsa template dir
make-cadir ${openvpn_ca}
cd ${openvpn_ca}


# Config vars file
if [ -f "/root/vars" ] ; then
    # Test if own parameters are present
    source /root/vars
else
    # Or ask user
    KEY_COUNTRY=$(whiptail --title "Input" --inputbox "KEY_COUNTRY ?" 10 60 FR 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then echo "Aborted!" && exit 1 ; fi

    KEY_PROVINCE=$(whiptail --title "Input" --inputbox "KEY_PROVINCE ?" 10 60 Paris 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then echo "Aborted!" && exit 1 ; fi

    KEY_CITY=$(whiptail --title "Input" --inputbox "KEY_CITY ?" 10 60 Paris 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then echo "Aborted!" && exit 1 ; fi

    KEY_ORG=$(whiptail --title "Input" --inputbox "KEY_ORG ?" 10 60 Nextdom 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then echo "Aborted!" && exit 1 ; fi

    KEY_EMAIL=$(whiptail --title "Input" --inputbox "KEY_EMAIL ?" 10 60 admin@example.com 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then echo "Aborted!" && exit 1 ; fi

    KEY_OU=$(whiptail --title "Input" --inputbox "KEY_OU ?" 10 60 Community 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then echo "Aborted!" && exit 1 ; fi

fi

sed -i "s#^export KEY_COUNTRY=.*#export KEY_COUNTRY=\"$KEY_COUNTRY\"#g" ${openvpn_ca}/vars
sed -i "s#^export KEY_PROVINCE=.*#export KEY_PROVINCE=\"$KEY_PROVINCE\"#g" ${openvpn_ca}/vars
sed -i "s#^export KEY_CITY=.*#export KEY_CITY=\"$KEY_CITY\"#g" ${openvpn_ca}/vars
sed -i "s#^export KEY_ORG=.*#export KEY_ORG=\"$KEY_ORG\"#g" ${openvpn_ca}/vars
sed -i "s#^export KEY_EMAIL=.*#export KEY_EMAIL=\"$KEY_EMAIL\"#g" ${openvpn_ca}/vars
sed -i "s#^export KEY_OU=.*#export KEY_OU=\"$KEY_OU\"#g" ${openvpn_ca}/vars
sed -i "s#^export KEY_NAME=.*#export KEY_NAME=\"server\"#g" ${openvpn_ca}/vars


cd ${openvpn_ca}
if [ ! -f "openssl.cnf" ] ; then
    ln -s openssl-1.0.0.cnf openssl.cnf
fi

# Building the CA
cd ${openvpn_ca}
source vars

# Clean all
./clean-all

export EASY_RSA="${EASY_RSA:-.}"

# build root CA
#./build-ca
"$EASY_RSA/pkitool" --initca

# generating the OpenVPN server certificate and key pair
#./build-key-server server
"$EASY_RSA/pkitool" --server server

# generating a robust Diffie-Hellman key
./build-dh

# generating a HMAC signature
openvpn --genkey --secret keys/ta.key


# Configurate OpenVPN server
cd ${openvpn_ca}/keys
cp -ax ca.crt server.crt server.key ta.key dh2048.pem /etc/openvpn/


# Adjusting the Server Networking Configuration
sed -i 's/^#net.ipv4.ip_forward=1.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p

# OpenVPN server config file
if [ -f "${install_files}/server.conf" ]; then
    cp ${install_files}/server.conf /etc/openvpn/server.conf
else
    gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server.conf
    sed -i 's/^proto udp.*/;proto udp/g' /etc/openvpn/server.conf
    sed -i 's/^;proto tcp.*/proto tcp/g' /etc/openvpn/server.conf
    sed -i 's/^proto .*/proto tcp/g' /etc/openvpn/server.conf
    sed -i 's/^port .*/port 8443/g' /etc/openvpn/server.conf
    sed -i 's/^;tls-auth .*/tls-auth ta.key 0/g' /etc/openvpn/server.conf
    sed -i '/^tls-auth ta.key 0/a key-direction 0' /etc/openvpn/server.conf
    sed -i 's/^;cipher .*/cipher AES-256-CBC/g' /etc/openvpn/server.conf
    sed -i '/^cipher AES-256-CBC/a auth SHA256' /etc/openvpn/server.conf
    sed -i 's/^;user .*/user nobody/g' /etc/openvpn/server.conf
    sed -i 's/^;group .*/group nogroup/g' /etc/openvpn/server.conf
    sed -i 's/^explicit-exit-notify /;explicit-exit-notify /g' /etc/openvpn/server.conf
fi


# Adjusting UFW configuration
#apt install -y ufw
##
#sed -i "/^# Don't delete these required lines.*/i # START OPENVPN RULES\n# NAT table rules\n*nat\n:POSTROUTING ACCEPT [0:0] \n# Allow traffic from OpenVPN client to eth0 (change to the interface you discovered)\n-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE\nCOMMIT\n# END OPENVPN RULES\n" /etc/ufw/before.rules
#sed -i 's/^DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
#ufw allow 1194/udp
#ufw allow OpenSSH
#ufw disable
#ufw enable


# Virtual interface
mkdir -p /dev/net
set +e
mknod /dev/net/tun c 10 200
set -e


# Starting and Enabling the OpenVPN Service
systemctl start openvpn@server
systemctl enable openvpn@server

ip addr show tun0

# Show IP
ip=$(hostname -I)
echo " >>>>  OpenVPN IP: ${ip} <<<<"
