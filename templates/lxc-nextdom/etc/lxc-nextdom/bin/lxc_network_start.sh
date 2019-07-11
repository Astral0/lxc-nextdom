#!/usr/bin/env bash

set -e

confdir=/etc/lxc-nextdom
conf=${confdir}/lxc-nextdom.conf

# Get current directory
set_root() {
    local this=`readlink -n -f $1`
    root=`dirname $this`
}
set_root $0


# Check if already up
if [ -f /sys/class/net/ndlan0/operstate ] ; then
  isup=$(cat /sys/class/net/ndlan0/operstate)
  if [ ${isup} = 'up' ] ; then
    exit 0
  fi
fi

set +e
ip link show ndlan0 >/dev/null 2>/dev/null
iret=$?
if [ "${iret}" == "0" ]; then
  exit 0
fi
set -e

# Read conf file and add network interface for LXC
if [[ -f ${conf} ]] ; then
  source ${conf}
  if [ -z ${primary} ] || [ -z ${mac} ] ; then
    echo "<F> Error reading file ${conf} ! Please run ${root}/lxc_network_setup.sh and retry."
    exit 1
  fi
  echo "<I> Starting ndlan0 bridged network interface"
  set +e
  ip link add ndlan0 link ${primary} address ${mac} type macvlan mode bridge
  ip link set ndlan0 up
  set -e
else
  echo "<F> Missing file ${conf} ! Please run ${root}/lxc_network_setup.sh and retry."
  exit 1
fi
