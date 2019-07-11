#!/usr/bin/env bash

# Check if already up and stop it
tostop=
if [ -f /sys/class/net/ndlan0/operstate ] ; then
  isup=$(cat /sys/class/net/ndlan0/operstate)
  if [ ${isup} = 'up' ] ; then
    tostop=1
  fi
fi

set +e
ip link show ndlan0 >/dev/null 2>/dev/null
iret=$?
if [ "${iret}" == "0" ]; then
    tostop=1
fi
set -e


if [ ! -z ${tostop} ] ; then
    echo "<I> Stopping ndlan0 bridged network interface"
    ip link set ndlan0 down
    ip link delete ndlan0
fi
