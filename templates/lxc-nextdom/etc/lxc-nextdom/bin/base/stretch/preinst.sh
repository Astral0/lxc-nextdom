#!/bin/bash

set +e

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND


# Try network configuration and wait if network isn't initialised
sleep 2
apt update
iret=$?
if [ ! "${iret}" == "0" ] ; then
    sleep 1
    apt update
    iret=$?
    if [ ! "${iret}" == "0" ] ; then
        sleep 2
        apt update
        iret=$?
        if [ ! "${iret}" == "0" ] ; then
            sleep 4
            apt update
            iret=$?
        fi
        if [ ! "${iret}" == "0" ] ; then
            echo " >>>> <F> Error : network configuration error inside container ! <<<<"
            exit ${iret}
        fi
    fi
fi

apt install -y sudo nano wget locales
locale-gen fr_FR.UTF-8


sed -i 's/# export LS_OPTIONS/export LS_OPTIONS/g' /root/.bashrc
sed -i 's/# eval /eval /g' /root/.bashrc
sed -i 's/# alias ll/alias ll/g' /root/.bashrc


# UFW




