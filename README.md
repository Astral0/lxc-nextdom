# lxc-nextdom
A set of scripts to build LXC containers for NextDom project



# Examples

## Install a simple empty container 

DHCP mode :
create-nextdom-container -n container-name -p empty

Fixed IP mode : 
create-nextdom-container -n container-name -p empty -i 192.168.50.90

## Install a container with Nextdom and restore Jeedom/Nextdom backup
container -n container-name -p nextdom -b /tmp/backup-User-3.3.24-2019-07-09-01h16m02.tar.gz

## Install a container with a developpement version of Nextdom
container -n container-name -p feature/ChartJS

where "feature/ChartJS" is a branch/PR/commit (can be juste "develop")


## Setup a OpenVPN container and a vpn client container
SERVER=lxc-s1
SERVER_IP=192.168.50.93
SERVER_PORT=8443

CLIENT=lxc-c1
CLIENT_IP=192.168.50.94

### Create the OpenVPN Server container
create-nextdom-container -n ${SERVER} -p openvpn-server -i ${SERVER_IP}/24 -r yes

### Create a Client container
create-nextdom-container -n ${CLIENT} -p empty -i ${192.168.50.94}/24 -r yes

### Create Client vpn key and copy it into Client container
lxc-attach -n ${SERVER} -- bash /root/vpn/make-client-config.sh ${CLIENT}
cp /var/lib/lxc/${SERVER}/rootfs/root/vpn/client-configs/files/${CLIENT}.ovpn /var/lib/lxc/${CLIENT}/rootfs/tmp/${CLIENT}.ovpn

### Configure OpenVPN client on Client container
lxc-attach -n ${CLIENT} -- bash /root/tmp/install/base/install_openvpn-client.sh /tmp/${CLIENT}.ovpn ${SERVER_IP} ${SERVER_PORT}



