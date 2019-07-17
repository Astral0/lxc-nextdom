#!/usr/bin/env bash

set -e

confdir=/etc/lxc-nextdom
conf=${confdir}/lxc-nextdom.conf


step_get_network_interface() {
    ## Get active network interface ##
    ETH=""
    set +e
    #ETH=$(routel | grep default |grep -v unreachable | head -1 | awk -F" " '{print $3}')
    ETH=$(ip route list | grep default |grep -v unreachable | head -1 | awk -F" " '{print $5}')
    set -e
    if [[ ${ETH} = "" ]] ; then
        echo "Error : can't get active network interface!"
        exit 1
    fi
}


step_generate_mac() {
    SEED=$(ls -a /tmp/ | tail -1)
    OID="00:16:3e"
    RAND=$(echo ${SEED} | md5sum | sed 's/\(..\)\(..\)\(..\).*/\1:\2:\3/')
    MAC="$OID:$RAND"
}


is_ip_address() {
    IP=$1
    if [[ ! "$IP" =~ (([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25[0-5])\.([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25[0-5])\.([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25[0-5])\.([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25$
       echo "<A> Problem with detected DHCP IP server : ${IP}"
       IP=""
    fi

}


step_get_dhcp_server() {
    ## get DHCP server ##
    DHCP=""
    set +e
    if [[ -f /var/lib/dhcp/dhclient.${ETH}.leases ]] ; then
        DHCP=$(grep dhcp-server-identifier /var/lib/dhcp/dhclient.${ETH}.leases | head -1 | awk -F" " '{print $3}' | sed "s/;//g")
    fi
    if [[ ${DHCP} = "" ]] && [[ -f /usr/bin/nmap ]] ; then
        DHCP=$(nmap --script broadcast-dhcp-discover -e ${ETH} 2>/dev/null |grep "Server Identifier" | awk -F" " '{print $4}')
    fi
    #
    if [[ ${DHCP} = "" ]] && [[ -f /sbin/dhclient ]] ; then
        DHCP=$((dhclient -v > /dev/null) 2>&1 | grep DHCPACK | awk -F" " '{print $5}')
    fi
    set -e
    #
    if [[ ! ${DHCP} = "" ]] ; then
        if [[ ! "$DHCP" =~ (([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25[0-5])\.([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25[0-5])\.([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25[0-5])\.([01]{,1}[0-9]{1,2}|2[0-4][0-9]|25[0-5]))$ ]]; then
           echo "<A> Problem with detected DHCP IP server : ${DHCP}"
           DHCP=""
        fi
    fi
    #
    if [[ ${DHCP} = "" ]] ; then
        echo "<A> Alarm Can't get DHCP server. You will need to setup container IP manually"
        exit 1
    fi
}



step_save_conf() {
    if [[ -f ${conf} ]] ; then rm -f ${conf} ; fi
    echo "<I> Creating mvlan0 bridged network interface conf file : ${conf}"
    touch ${conf}
    chmod 600 ${conf}
    echo "primary=${ETH}" >> ${conf}
    echo "mac=${MAC}" >> ${conf}
    echo "dhcp=${DHCP}" >> ${conf}
}



# ======================================================================
# Main
if [ $(id -u) != 0 ] ; then
    echo "Les droits de super-utilisateur (root) sont requis pour installer le LXC NextDom"
    echo "Veuillez lancer sudo $0 ou connectez-vous en tant que root, puis relancez $0"
    exit 1
fi


step_get_network_interface

step_generate_mac

step_get_dhcp_server

step_save_conf

