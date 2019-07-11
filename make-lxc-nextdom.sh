#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Missing version argument... Exiting."
  exit 1
fi

dirn="lxc-nextdom"
vers=$1


set_root() {
    local this=`readlink -n -f $1`
    root=`dirname $this`
}
set_root $0

new=${root}/${dirn}-${vers}
if [ ! -d "${new}" ]; then
  mkdir -p ${new}
fi

echo "Creation du contenu dans le repertoire ${new}"
#read -n1 -r -p "Press space to continue..." key

set -e

# -----------------------------------------------------------------------------------------
if [ -d "${root}/templates/${dirn}" ] ; then
    cp -ax ${root}/templates/${dirn}/* ${new}/
else
    echo "<F> Directory not present : ${root}/templates/${dirn} !"
    exit 1
fi

# Debian config files
CONTROL="${new}/DEBIAN/control"
POSTINST="${new}/DEBIAN/postinst"
POSTRM="${new}/DEBIAN/postrm"
PREINST="${new}/DEBIAN/preinst"
PRERM="${new}/DEBIAN/prerm"

# Generation of control Debian file
sed -i "s/^Package:.*/Package: ${dirn}/g" ${CONTROL}
sed -i "s/^Version:.*/Version: ${vers}/g" ${CONTROL}

# Empty conf file
CONF="${new}/etc/lxc-nextdom/lxc-nextdom.conf"
sed -i "s/^primary=.*/primary=/g" ${CONF}
sed -i "s/^mac=.*/mac=/g" ${CONF}
sed -i "s/^dhcp=.*/dhcp=/g" ${CONF}

# Correction sur les droits
chmod 755 ${PREINST}
chmod 755 ${POSTINST}
chmod 755 ${PRERM}
chmod 755 ${POSTRM}

#find . -name "*.sh" -exec chmod 755 {} \
chmod 755 ${new}/usr/bin/create-nextdom-container.sh
chmod 755 ${new}/usr/bin/delete-nextdom-container.sh
chmod 755 ${new}/etc/lxc-nextdom/bin/*.sh

dpkg-deb --build ${new}

echo " >>> COMPLETED <<<"

