#!/usr/bin/env bash

set -e

# Variables
VAR_DIR=/var/lib/lxc-nextdom
ETC_DIR=/etc/lxc-nextdom
#TEMPLATES_DIR=/usr/share/lxc-nextdom/config
LXC_DIR=/var/lib/lxc
DEB_VERS=stretch

# Arguments
usage() { echo "Usage: $0
  [-h <help>]
  [-n <container name (default: lxc-nextdom)>]
  [-p <product type ('stable' or 'empty' or branche/pr name, default:stable)]
  [-i <container IP (CIDR format, ex. 192.168.1.100/24 - Empty=DHCP )>]
  [-r yes <replace container>]
  [-b <backupfile to restore inside container (full path to restore or leave empty to detect last backup on current host and copy inside container)>]
" 1>&2; exit 1; }

while getopts "n:p:i:r:b:" option; do
    case "${option}" in
        h)
            usage
            ;;
        n)
            LXC_NAME=${OPTARG}
            ;;
        p)
            NEXTDOM_VERSION=${OPTARG}
            ;;
        i)
            LXC_CIDR=${OPTARG}
            ;;
        r)
            LXC_REPLACE=${OPTARG}
            ;;
        b)
            NEXTDOM_BACKUP=${OPTARG}
            ;;
        *)
            usage
            exit -1
            ;;
    esac
done
shift $((OPTIND-1))

LXC_NAME=${LXC_NAME:-"lxc-nextdom"}
NEXTDOM_VERSION=${NEXTDOM_VERSION:-"stable"}

#echo $LXC_NAME
#echo $NEXTDOM_VERSION
#echo $LXC_CIDR
echo $LXC_REPLACE

ROOT_CONTAINER=${LXC_DIR}/${LXC_NAME}


# -----------------------------------------------------------------------------
print_log_in() {
    txt=$1
    printf "${txt}"
}


print_log_ok() {
    echo " OK"
}

# -----------------------------------------------------------------------------


# Test if root user
if [ $(id -u) != 0 ] ; then
    print_log_in "\n<F> Les droits de super-utilisateur (root) sont requis pour installer le LXC NextDom"
    print_log_in "\nVeuillez lancer sudo $0 ou connectez-vous en tant que root, puis relancez $0\n"
    exit 1
fi


# Get current directory
set_root() {
    local this=`readlink -n -f $1`
    root=`dirname $this`
}
set_root $0


# Test if backup file exists
if [ ! -z ${NEXTDOM_BACKUP} ] ; then
    if [ -f "${NEXTDOM_BACKUP}" ] ; then
        backupfile=${NEXTDOM_BACKUP}
    else
        print_log_in "\n<A> Missing backup file : ${NEXTDOM_BACKUP}\n"
        exit 1
    fi
fi


# -----------------------------------------------------------------------------

step_verify_missing_packages() {
    ## Install missing packages (lxc, ...) ##
    LIST=""
    for PKG in lxc \
               bridge-utils \
               debootstrap \
; do
        if ! dpkg-query -W -f='${Status}' ${PKG} | grep "ok installed"; then LIST="${PKG} ${LIST}" ; fi
    #
    done
    #
    if [[ ! ${LIST} = "" ]] ; then
        print_log_in "\n<F> Missing Debian package : ${LIST}\n"
        exit 1
    fi
}


step_bootstrap_lxc() {
    ## Download and boostrap LXC container ##
    # Test if container already exists
    if [[ -d "${ROOT_CONTAINER}/rootfs" ]]; then
        if [ ! -z ${LXC_REPLACE} ] ; then
            print_log_in "\n<F> Container ${ROOT_CONTAINER} already exists! Erasing!\n"
            set +e
            lxc-stop -n ${LXC_NAME}
            set -e
            lxc-destroy -n ${LXC_NAME}
        else
            print_log_in "\n<F> Container ${ROOT_CONTAINER} already exists! Stopping!\n"
            exit 1
        fi
    fi
    #
    mkdir -p ${ROOT_CONTAINER}
#    lxc-create -n ${LXC_NAME} -t debian -f ${TEMPLATES_DIR}/lxc-ndlan.conf -P ${LXC_DIR}  -- -r ${DEB_VERS}
    lxc-create -n ${LXC_NAME} -t debian -f /usr/share/doc/lxc/examples/lxc-macvlan.conf -P ${LXC_DIR}  -- -r ${DEB_VERS}
}


step_generate_mac() {
    #SEED=$(basename ${root})
    SEED="$(ls -a /tmp/ | tail -1)-${LXC_NAME}"
    OID="00:16:3e"
    RAND=$(echo ${SEED} | md5sum | sed 's/\(..\)\(..\)\(..\).*/\1:\2:\3/')
    MAC="$OID:$RAND"
}


step_get_gateway() {
    GA=$(ip route | grep default | tail -1 | awk -F" " '{print $3}')
    GATEWAY=${GA:-"192.168.x.x"}
}

step_save_list() {
    conf=${VAR_DIR}/list


    if [[ -f "${conf}" ]] ; then rm -f ${conf} ; fi
    touch ${conf}
    chmod 600 ${conf}
    echo "rootdir=${root}" >> ${conf}
    echo "root_container=${root_container}" >> ${conf}
    echo "name_container=${name_container}" >> ${conf}
    echo "interface=${ETH}" >> ${conf}
}


step_prepare_config() {
    configold=${ROOT_CONTAINER}/config.old
    config=${ROOT_CONTAINER}/config
    if [[ -f "${configold}" ]] ; then rm -f ${configold} ; fi
    if [[ -f "${config}" ]] ; then cp -ax ${config} ${configold} ; fi
    sleep 1 &&
    #
    # Hack for Ubuntu LXC (that do not setup network in container config file!)
    if [ -z "$(grep "^lxc.network.type" ${config})" ] ; then echo "lxc.network.type = macvlan" >>${config} ; fi
    if [ -z "$(grep "^lxc.network.flags" ${config})" ] ; then echo "lxc.network.flags = up" >>${config} ; fi
    if [ -z "$(grep "^lxc.network.link" ${config})" ] ; then echo "lxc.network.link = eth0" >>${config} ; fi
    if [ -z "$(grep "^lxc.network.hwaddr" ${config})" ] ; then echo "lxc.network.hwaddr = 4a:49:43:49:79:bd" >>${config} ; fi
    if [ -z "$(grep "^lxc.network.ipv4" ${config})" ] ; then echo "lxc.network.ipv4 = 10.2.3.4/24" >>${config} ; fi
    #
    # Change bridged interface
    sed -i 's/^lxc.network.link.*/lxc.network.link = ndlan0/g' ${config}
    #
    # Comment ipv4 if DHCP mode or setup IP
    if [ -z ${LXC_CIDR} ] ; then
        sed -i 's/^lxc.network.ipv4/#lxc.network.ipv4/g' ${config}
        sed -i "/^lxc.network.ipv4/a #lxc.network.ipv4.gateway = ${GATEWAY}" ${config}
    else
        sed -i "s#^lxc.network.ipv4.*#lxc.network.ipv4= ${LXC_CIDR}#g" ${config}
        sed -i 's/^auto eth0/#auto eth0/g' ${ROOT_CONTAINER}/rootfs/etc/network/interfaces
        sed -i 's/^iface eth0/#iface eth0/g' ${ROOT_CONTAINER}/rootfs/etc/network/interfaces
        sed -i "/^lxc.network.ipv4/a lxc.network.ipv4.gateway = ${GATEWAY}" ${config}
    fi
    #
    # Suppress ipv6 compatibility
    sed -i 's/^lxc.network.ipv6/#lxc.network.ipv6/g' ${config}
    #
    # Change MAC
    sed -i "s/^lxc.network.hwaddr.*/lxc.network.hwaddr = ${MAC}/g" ${config}
    #
    # Add pre script
    echo "lxc.hook.pre-start = /etc/lxc-nextdom/bin/lxc_network_start.sh" >>${config}
    echo "#lxc.hook.post-stop = " >>${config}
    #
    # Autostart container
    echo "lxc.start.auto = 1" >>${config}
    #
    # Copy last jeedom/nextdom backup from host if exists
    backupfile=""
    if [ ! -z ${NEXTDOM_BACKUP} ] ; then
        if [ -f "${NEXTDOM_BACKUP}" ] ; then
            backupfile=${NEXTDOM_BACKUP}
        fi
    fi
    #
    if [ -z ${NEXTDOM_BACKUP} ] ; then
        if [ -d "/var/www/html/backup" ] ; then
            backupfile=$(ls -atr /var/www/html/backup/backup* 2>/dev/null | tail -1) >/dev/null 2>/dev/null
        fi
        if [ -d "/var/lib/nextdom/backup" ] ; then
            if [ -z ${backupfile} ] ; then
                backupfile=$(ls -atr /var/lib/nextdom/backup/backup* 2>/dev/null | tail -1) >/dev/null 2>/dev/null
            fi
        fi
    fi
    #
    if [ -f "${backupfile}" ] ; then
        mkdir -p ${ROOT_CONTAINER}/rootfs/var/lib/nextdom/backup
        chmod 755 ${ROOT_CONTAINER}/rootfs/var/lib/nextdom/backup
        cp -ax ${backupfile} ${ROOT_CONTAINER}/rootfs/var/lib/nextdom/backup
    fi
    #
    # Add container hostname in /etc/hosts
    echo "127.0.1.1       ${LXC_NAME}"  >> ${ROOT_CONTAINER}/rootfs/etc/hosts
    #
    # Add container in file list
    if [ ! -d "${VAR_DIR}" ]; then mkdir -p ${VAR_DIR} ; fi
    listcont="${VAR_DIR}/list"
    isok=""
    set +e
    if [ -f ${listcont} ] ; then
        isok=$(grep "^${LXC_NAME}$" ${listcont})
    fi
    if [ -z ${isok} ] ; then
        echo ${LXC_NAME} >> ${listcont}
    fi
    set -e
}


step_start_container() {

    # Start container
    lxc-start -n ${LXC_NAME}
    #
    # Install Nextdom inside container
    arg=
    if [ ! ${NEXTDOM_VERSION} = "empty" ] ; then
        if [ ${NEXTDOM_VERSION} = "stable" ] ; then
            cp -ax /etc/lxc-nextdom/bin/install_nextdom.sh ${ROOT_CONTAINER}/rootfs/root/install.sh
        elif [ ${NEXTDOM_VERSION} = "grafana" ] ; then
            cp -ax /etc/lxc-nextdom/bin/install_grafana.sh ${ROOT_CONTAINER}/rootfs/root/install.sh
            arg="toto titi"
        elif [ ${NEXTDOM_VERSION} = "influxdb" ] ; then
            cp -ax /etc/lxc-nextdom/bin/install_influxdb.sh ${ROOT_CONTAINER}/rootfs/root/install.sh
            arg="tutu tata"
        elif [ ${NEXTDOM_VERSION} = "nextdom2influxdb" ] ; then
            cp -ax /etc/lxc-nextdom/bin/install_nextdom2influxdb.sh ${ROOT_CONTAINER}/rootfs/root/install.sh
            arg="ip1 ip2"
        else
            cp -ax /etc/lxc-nextdom/bin/install_nextdom.sh ${ROOT_CONTAINER}/rootfs/root/install.sh
            #sed -i "s#NEXTDOM_VERSION#${NEXTDOM_VERSION}#g" ${ROOT_CONTAINER}/rootfs/root/install_nextdom.sh
            arg="${NEXTDOM_VERSION}"
        fi
        chmod 755 ${ROOT_CONTAINER}/rootfs/root/install.sh
        sleep 2
        lxc-attach -n ${LXC_NAME} -- bash -x /root/install.sh ${arg}
    fi
    #
    # Just copy backup file if detected on host
    backupfile=
    if [ -z ${NEXTDOM_BACKUP} ] ; then
        if [ -d "/var/www/html/backup" ] ; then
            backupfile=$(ls -atr /var/www/html/backup/backup* 2>/dev/null | tail -1) >/dev/null 2>/dev/null
        fi
        if [ -d "/var/lib/nextdom/backup" ] ; then
            if [ -z ${backupfile} ] ; then
                backupfile=$(ls -atr /var/lib/nextdom/backup/backup* 2>/dev/null | tail -1) >/dev/null 2>/dev/null
            fi
        fi
    fi
    if [ -f "${backupfile}" ] ; then
        mkdir -p ${ROOT_CONTAINER}/rootfs/var/lib/nextdom/backup
        chmod 755 ${ROOT_CONTAINER}/rootfs/var/lib/nextdom/backup
        cp -ax ${backupfile} ${ROOT_CONTAINER}/rootfs/var/lib/nextdom/backup
        print_log_in "\n<I> Backup file copied. You can restore it from Nextdom web interface.\n"
    fi
    #
    # Show IP adress
    ip=$(lxc-info -n ${LXC_NAME} -iH)
    if [ -z ${ip} ] ; then
        sleep 1
        ip=$(lxc-info -n ${LXC_NAME} -iH)
    fi
    if [ -z ${ip} ] ; then
        sleep 2
        ip=$(lxc-info -n ${LXC_NAME} -iH)
    fi
    if [ -z ${ip} ] ; then
        sleep 3
        ip=$(lxc-info -n ${LXC_NAME} -iH)
    fi
    echo "\n\n>>>>> Open Nextdom Website : https://${ip} <<<<<\n\n"

}




# ======================================================================

print_log_in "step_verify_missing_packages ... "
step_verify_missing_packages
print_log_ok

print_log_in "step_bootstrap_lxc ..."
step_bootstrap_lxc
print_log_ok

print_log_in "step_generate_mac ..."
step_generate_mac
print_log_ok

print_log_in "step_get_gateway ..."
step_get_gateway
print_log_ok

print_log_in "step_prepare_config ..."
step_prepare_config
print_log_ok

print_log_in "step_start_container ..."
step_start_container
print_log_ok
