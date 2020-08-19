#!/bin/bash

#DEBIAN_FRONTEND=noninteractive
#export DEBIAN_FRONTEND

VEOLIA_LOGIN=$1
VEOLIA_PASSWORD=$2


echo " >>>> Installation de Veolia-idf <<<<"

# Get current directory
set_root() {
    local this=`readlink -n -f $1`
    root=`dirname $this`
}
set_root $0
cd ${root}

CFG=${root}/conso_veolia/config.py



# Prerequis
apt update
apt -y upgrade
apt install -y whiptail


# Setup login and password
if [ -z ${VEOLIA_LOGIN} ] ; then
    VEOLIA_LOGIN=$(whiptail --title "Input" --inputbox "VEOLIA Account Email" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then VEOLIA_LOGIN= ; fi
fi

if [ -z ${VEOLIA_PASSWORD} ] ; then
    VEOLIA_PASSWORD=$(whiptail --title "Input" --inputbox "VEOLIA Account Password" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$? && if [ ! $exitstatus = 0 ]; then VEOLIA_PASSWORD= ; fi
fi

if [ -z $VEOLIA_LOGIN ] || [ -z $VEOLIA_PASSWORD ]; then
    whiptail --title "VEOLIA Account informations missing..." --msgbox "Please add your credentials manually in ." 10 60
fi



# Prerequis
apt install -y software-properties-common gnupg wget hostname git nano sudo

apt install -y python3 python3-pip xvfb iceweasel
pip3 install selenium pyvirtualdisplay urllib3

cd ${root}
# Install Gecko driver
wget https://github.com/mozilla/geckodriver/releases/download/v0.26.0/geckodriver-v0.26.0-linux64.tar.gz
tar xzfz geckodriver-v0.26.0-linux64.tar.gz
mv geckodriver /usr/local/bin
rm geckodriver-v0.26.0-linux64.tar.gz

#32bit : wget https://github.com/mozilla/geckodriver/releases/download/v0.26.0/geckodriver-v0.26.0-linux32.tar.gz && tar xzfz geckodriver-v0.26.0-linux32.tar.gz && sudo mv geckodriver /usr/local/bin && rm geckodriver-v0.26.0-linux32.tar.gz

# Clone repo
git clone -b patch-1 https://github.com/Flobul/conso_veolia.git

cd ${root}/conso_veolia
ln -s /usr/local/bin/geckodriver geckodriver

# Adjust config file
cp -ax config.py.sample config.py

if [ ! -z $VEOLIA_LOGIN ]; then
    sed -i "s/^.*VEOLIA_LOGIN =.*/VEOLIA_LOGIN = '$VEOLIA_LOGIN'/g" $CFG
fi

if [ ! -z $VEOLIA_PASSWORD ]; then
    sed -i "s/^.*VEOLIA_PASSWORD =.*/VEOLIA_PASSWORD = '$VEOLIA_PASSWORD'/g" $CFG
fi


sed -i "s/^.*v.handle_csv()/#v.handle_csv()/g" ${root}/conso_veolia/get_veolia_idf_consommation.py



# Locales
locale-gen fr_FR
locale-gen fr_FR.UTF-8
#update-locale LANG=fr_FR.UTF-8
#update-locale LANG="fr_FR.UTF-8" LANGUAGE="fr_FR"


