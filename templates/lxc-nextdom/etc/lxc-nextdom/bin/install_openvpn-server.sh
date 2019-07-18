#!/bin/bash

# OpenVPN Deiban 9 version

set -e

arg1=$1
arg2=$2

echo " >>>> Installation de OpenVPN Server <<<<"

# Params
openvpn_root="/root/vpn"
openvpn_ca=${openvpn_root}/EasyRSA
clients="/root/client-configs"

# Prerequis
#apt update
#apt -y upgrade
#apt install -y openvpn wget hostname whiptail
#apt install -y openvpn easy-rsa wget hostname whiptail

#wget https://raw.githubusercontent.com/Angristan/OpenVPN-install/master/openvpn-install.sh
#chmod +x openvpn-install.sh
#./openvpn-install.sh



# Creation du repertoire
if [ -f ${openvpn_root} ] || [ -d ${openvpn_root} ] ; then
    if (whiptail --title "${openvpn_root} deja present" --yesno "Effacer ${openvpn_root} ?" 10 60) then
        rm -rf ${openvpn_root}
    fi
fi
mkdir -p ${openvpn_root}

wget -qO- https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.6/EasyRSA-unix-v3.0.6.tgz | tar xfz - -C ${openvpn_root}/
cd ${openvpn_root}/
ln -s EasyRSA-v3.0.6 EasyRSA

cd ${openvpn_ca}
cp vars.example vars


## Create easy-rsa template dir
#make-cadir ${openvpn_ca}

# Configu vars file
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

#sed -i "s#^export KEY_COUNTRY=.*#export KEY_COUNTRY=\"$KEY_COUNTRY\"#g" ${openvpn_ca}/vars
#sed -i "s#^export KEY_PROVINCE=.*#export KEY_PROVINCE=\"$KEY_PROVINCE\"#g" ${openvpn_ca}/vars
#sed -i "s#^export KEY_CITY=.*#export KEY_CITY=\"$KEY_CITY\"#g" ${openvpn_ca}/vars
#sed -i "s#^export KEY_ORG=.*#export KEY_ORG=\"$KEY_ORG\"#g" ${openvpn_ca}/vars
#sed -i "s#^export KEY_EMAIL=.*#export KEY_EMAIL=\"$KEY_EMAIL\"#g" ${openvpn_ca}/vars
#sed -i "s#^export KEY_OU=.*#export KEY_OU=\"$KEY_OU\"#g" ${openvpn_ca}/vars
#sed -i "s#^export KEY_NAME=.*#export KEY_NAME=\"server\"#g" ${openvpn_ca}/vars


sed -i "s/^#set_var EASYRSA_REQ_COUNTRY.*/set_var EASYRSA_REQ_COUNTRY    \"$KEY_COUNTRY\"/g" ${openvpn_ca}/vars
sed -i "s/^#set_var EASYRSA_REQ_PROVINCE.*/set_var EASYRSA_REQ_PROVINCE   \"$KEY_PROVINCE\"/g" ${openvpn_ca}/vars
sed -i "s/^#set_var EASYRSA_REQ_CITY.*/set_var EASYRSA_REQ_CITY       \"$KEY_CITY\"/g" ${openvpn_ca}/vars
sed -i "s/^#set_var EASYRSA_REQ_ORG.*/set_var EASYRSA_REQ_ORG        \"$KEY_ORG\"/g" ${openvpn_ca}/vars
sed -i "s/^#set_var EASYRSA_REQ_EMAIL.*/set_var EASYRSA_REQ_EMAIL      \"$KEY_ORG\"/g" ${openvpn_ca}/vars
sed -i "s/^#set_var EASYRSA_REQ_OU.*/set_var EASYRSA_REQ_OU         \"$KEY_ORG\"/g" ${openvpn_ca}/vars

sed -i "s/^#set_var EASYRSA_REQ_CN.*/set_var EASYRSA_REQ_CN         \"server\"/g" ${openvpn_ca}/vars





# Building the CA
./easyrsa init-pki
./easyrsa --batch build-ca nopass


# Creating the Server Certificate, Key, and Encryption Files
./easyrsa --batch gen-req server nopass
cp -ax ${openvpn_ca}/pki/private/server.key /etc/openvpn/
./easyrsa --batch --req-cn=server gen-req server nopass
./easyrsa --batch sign-req server server
cp -ax ${openvpn_ca}/pki/issued/server.crt /etc/openvpn/
cp -ax ${openvpn_ca}/pki/ca.crt /etc/openvpn/


# create a strong Diffie-Hellman key
./easyrsa --batch gen-dh
openvpn --genkey --secret ta.key
cp -ax ${openvpn_ca}/ta.key /etc/openvpn/
cp -ax ${openvpn_ca}/pki/dh.pem /etc/openvpn/


# Generating a Client Certificate and Key Pair
mkdir -p ${clients}/keys
chmod -R 700 ${clients}
./easyrsa --batch gen-req client1 nopass
cp -ax  ${openvpn_ca}/pki/private/client1.key ${clients}/keys/
./easyrsa --batch sign-req client client1
cp ${openvpn_ca}/ta.key ~/client-configs/keys/
cp /etc/openvpn/ca.crt ~/client-configs/keys/


# Adjusting the Server Networking Configuration
sed -i 's/^#net.ipv4.ip_forward=1.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p


# Adjusting UFW configuration
apt install -y ufw
#
sed -i "/^# Don't delete these required lines.*/i # START OPENVPN RULES\n# NAT table rules\n*nat\n:POSTROUTING ACCEPT [0:0] \n# Allow traffic from OpenVPN client to eth0 (change to the interface you discovered)\n-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE\nCOMMIT\n# END OPENVPN RULES\n" /etc/ufw/before.rules
sed -i 's/^DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
ufw allow 1194/udp
ufw allow OpenSSH
ufw disable
ufw enable


# Starting and Enabling the OpenVPN Service
systemctl start openvpn@server
systemctl enable openvpn@server

ip addr show tun0



exit 0

if [ ! -f "openssl.cnf" ] ; then
    ln -s openssl-1.0.0.cnf openssl.cnf
fi

source vars

# Clean all
./clean-all

# build root CA
./build-ca

# generating the OpenVPN server certificate and key pair
./build-key-server server






# Show IP
ip=$(hostname -I)
echo " >>>>  Please open ${ip} <<<<"



