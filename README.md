# lxc-nextdom
A set of scripts to build LXC containers for NextDom project



# Example

SERVER=lxc-s1
CLIENT=lxc-c1

create-nextdom-container -n ${SERVER} -p openvpn-server -i 192.168.50.93/24 -r yes

create-nextdom-container -n ${CLIENT} -p empty -i 192.168.50.94/24 -r yes

lxc-attach -n ${SERVER} -- bash /root/vpn/make-client-config.sh ${CLIENT}

cp /var/lib/lxc/${SERVER}/roots/root/vpn/client-configs/${CLIENT}.ovpn cp /var/lib/lxc/${SERVER}/roots/tmp/

lxc-attach -n ${SERVER} -- bash /root/tmp/install/base/install_openvpn-client.sh /tmp/${CLIENT}.ovpn



