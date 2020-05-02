#!/bin/bash

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

arg1=$1
arg2=$2

echo " >>>> Installation de Samba <<<<"

# Check TERM
if [ -z ${TERM} ] ; then
    export TERM=vt100
else
    set +e
    isscreen=$(echo $TERM | grep "screen")
    if [ ! -z ${isscreen} ] ; then
        export TERM=vt100
    fi
    set -e
fi

# Prerequis
apt update
apt -y upgrade
apt install -y samba

# Add samba user
adduser sambauser --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
echo "sambauser:password" | chpasswd

echo "WARNING! The Samba template isn't finished yet!"

