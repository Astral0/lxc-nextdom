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
#apt update
#apt install -y firefox firefox-geckodriver python3-pip xvfb xserver-xephyr x11-utils
# installes via pip3 : python3-selenium python3-colorama python-urllib3 

#apt install -y x11-xserver-utils

apt install -y python3 xvfb iceweasel
pip3 install -y selenium pyvirtualdisplay urllib3
wget https://github.com/mozilla/geckodriver/releases/download/v0.26.0/geckodriver-v0.26.0-linux64.tar.gz && tar xzfz geckodriver-v0.26.0-linux64.tar.gz && sudo mv geckodriver /usr/local/bin && rm geckodriver-v0.26.0-linux64.tar.gz
#32bit : wget https://github.com/mozilla/geckodriver/releases/download/v0.26.0/geckodriver-v0.26.0-linux32.tar.gz && tar xzfz geckodriver-v0.26.0-linux32.tar.gz && sudo mv geckodriver /usr/local/bin && rm geckodriver-v0.26.0-linux32.tar.gz
git clone -b master https://github.com/Flobul/conso_veolia.git


# Locales
locale-gen fr_FR
locale-gen fr_FR.UTF-8
update-locale LANG=fr_FR.UTF-8
update-locale LANG="fr_FR.UTF-8" LANGUAGE="fr_FR"

#mkdir -p /opt
#cd /opt
#git clone https://github.com/s0nik42/veolia-idf
#cd veolia-idf
#git pull
#chmod ugo+x veolia-idf-domoticz.py
#cp  config.json.exemple config.json
#pip3 install -r requirements.txt


echo "WARNING! The Veolia IDF template isn't finished yet!"
