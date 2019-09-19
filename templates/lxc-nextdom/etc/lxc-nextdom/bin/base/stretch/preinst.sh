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

apt install -y sudo nano wget


# UFW




