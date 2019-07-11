#!/bin/bash

arg=$1

if [ ! -d "${arg}" ]; then
  echo "${arg} n'est pas un repertoire, on sort"
  exit 1
fi

echo "Creation du paquet debian ${arg}.deb a partir du repertoire ${arg}"
#read -n1 -r -p "Press space to continue..." key

set -e

dpkg-deb --build ${arg}

if [ -d /export/ ] ; then
    mv ${arg}.deb /export/
fi

