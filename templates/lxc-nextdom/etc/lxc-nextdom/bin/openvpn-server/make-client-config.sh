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
