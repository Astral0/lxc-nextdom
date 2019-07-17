#!/usr/bin/env bash

set -e

# Variables
VAR_DIR=/var/lib/lxc-nextdom

# Arguments
usage() { echo "Usage: $0 [-h <help>] [-n <container name>]" 1>&2; exit 1; }

while getopts "n:" option; do
    case "${option}" in
        h)
            usage
            ;;
        n)
            LXC_NAME=${OPTARG}
            ;;
        *)
            usage
            exit -1
    esac
done
shift $((OPTIND-1))

#echo $LXC_NAME

# -----------------------------------------------------------------------------
print_log_in() {
    txt=$1
    printf "${txt}"
}


print_log_ok() {
    echo " OK"
}

# -----------------------------------------------------------------------------

# Test argument
if [  -z ${LXC_NAME} ] ; then
    print_log_in "<F> Please specify a Container name!\n"
    exit 1
fi

# Erase container
set +e
isrunning=$(lxc-info -n ${LXC_NAME} --state |awk -F" " '{print $2}')
if [ "${isrunning}" == 'RUNNING' ] ; then
  lxc-stop -n ${LXC_NAME} 2>/dev/null
fi
lxc-destroy -n ${LXC_NAME} 2>/dev/null
set -e

# Remove container in file list
listcont="${VAR_DIR}/list"
isok=""
set +e
if [ -f ${listcont} ] ; then
    sed -i "/^${LXC_NAME}$/d" ${listcont}
fi
set -e

print_log_ok
