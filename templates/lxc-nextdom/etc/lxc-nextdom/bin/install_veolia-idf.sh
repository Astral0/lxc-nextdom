#!/bin/bash

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

arg1=$1
arg2=$2

echo " >>>> Installation de Veolia-idf <<<<"

# Prerequis
apt update
apt -y upgrade
apt install -y software-properties-common gnupg wget hostname git
#add-apt-repository non-free
apt update
apt install -y firefox firefox-geckodriver python3-pip xvfb xserver-xephyr x11-utils
# installes via pip3 : python3-selenium python3-colorama python-urllib3 

apt install -y x11-xserver-utils


# Locales
locale-gen fr_FR
locale-gen fr_FR.UTF-8
update-locale LANG=fr_FR.UTF-8
update-locale LANG="fr_FR.UTF-8" LANGUAGE="fr_FR"

mkdir -p /opt
cd /opt
git clone https://github.com/s0nik42/veolia-idf
cd veolia-idf
git pull

chmod ugo+x veolia-idf-domoticz.py
cp  config.json.exemple config.json

pip3 install -r requirements.txt


echo "WARNING! The Veolia IDF template isn't finished yet!"
