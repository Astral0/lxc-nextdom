#!/bin/bash

set -e
set -x

#arg1=$1
#arg2=$2

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo " >>>> Installation de Zoneminder <<<<"

# parameters
MQTT_IP=
MQTT_USER=
MQTT_PASS=

if [ -z ${MQTT_IP} ] || [ -z ${MQTT_USER} ] || [ -z ${MQTT_PASS} ] ; then
    echo "<F> Error ! Missing parameters MQTT_IP (-m), MQTT_USER (-u) or MQTT_PASS (-v) !"
	exit 1
fi


# Install Zoneminder
apt update
apt upgrade -y

# Install prerequisites
apt install -y software-properties-common gnupg wget ca-certificates apt-transport-https sudo git
apt install -y apache2


# Install Zoneminder
wget -O -  https://zmrepo.zoneminder.com/debian/archive-keyring.gpg  | sudo apt-key add -

source /etc/os-release
test $VERSION_ID = "7" && echo "deb  https://zmrepo.zoneminder.com/debian/master  wheezy/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "8" && echo "deb  https://zmrepo.zoneminder.com/debian/master  jessie/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "9" && echo "deb  https://zmrepo.zoneminder.com/debian/master  stretch/" >/etc/apt/sources.list.d/zm.list
test $VERSION_ID = "10" && echo "deb  https://zmrepo.zoneminder.com/debian/master  buster/" >/etc/apt/sources.list.d/zm.list
apt update

apt -y install zoneminder

# Enable the systemd service
systemctl enable zoneminder.service

a2enconf zoneminder
a2enmod rewrite
a2enmod cgi

# PHP path
php_path=$(php --ini | head -n 1 | sed -E "s/.*Path: (.*)\/cli/\\1/")
php_ini="${php_path}/apache2/php.ini"
if [ ! -f ${php_ini} ] ; then
    echo "<F> Error : can't get php.ini file !"
	exit 1
fi
sed -i 's#^.*date.timezone =#date.timezone = Europe/Paris#g' /etc/php/7.0/apache2/php.ini

# Restart server
service apache2 reload
systemctl daemon-reload
systemctl restart zoneminder

# Generate a self-signed Certificat for Nginx
apt install -y openssl
mkdir -p /etc/zm/apache2/ssl/
cd /etc/zm/apache2/ssl/
openssl genrsa -out zoneminder.key 2048
openssl req -new -key zoneminder.key -out zoneminder.csr -subj "/C=FR/ST=Paris/L=Paris/O=Global Security/OU=IT Department/CN=example.com"
openssl x509 -req -days 3650 -in zoneminder.csr -signkey zoneminder.key -out zoneminder.crt
#
echo " "
echo ">>> Self-signed SSL Certificate created in /etc/zm/apache2/ssl/  <<<"
echo ">>> Please feel free to use your own Certificate                 <<<"
echo " "

a2enmod ssl
a2ensite default-ssl
systemctl reload apache2

# For deactivate HTTP access, uncomment below :
#a2dissite 000-default



# Installation of ZM Event Notification
# -------------------------------------
cd /usr/bin/
git clone  https://github.com/pliablepixels/zmeventnotification.git 
cd /usr/bin/zmeventnotification/

# Change port
sed -i 's/^.*port =.*/port = 9000/g' zmeventnotification.ini

# Enable MQTT
sed -i '/^\[mqtt\]$/,/^\[/ s/^enable =.*/enable = yes/' zmeventnotification.ini
sed -i "/^\[mqtt\]$/,/^\[/ s/^.*server =.*/server = $MQTT_IP/" zmeventnotification.ini
sed -i "/^\[mqtt\]$/,/^\[/ s/^.*username =.*/username = $MQTT_USER/" zmeventnotification.ini
sed -i "/^\[mqtt\]$/,/^\[/ s/^.*password =.*/password = $MQTT_PASS/" zmeventnotification.ini

# Enable SSL
sed -i "/^\[ssl\]$/,/^\[/ s#^.*enable =.*#enable = yes#" zmeventnotification.ini
sed -i "/^\[ssl\]$/,/^\[/ s#^cert =.*#cert = /etc/zm/apache2/ssl/zoneminder.crt#" zmeventnotification.ini
sed -i "/^\[ssl\]$/,/^\[/ s#^key =.*#key = /etc/zm/apache2/ssl/zoneminder.key#" zmeventnotification.ini

# Active debug output
sed -i "/^\[customize\]$/,/^\[/ s#^.*console_logs =.*#console_logs = yes#" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#^.*read_alarm_cause =.*#read_alarm_cause = yes#" zmeventnotification.ini

# Picture URL
url=127.0.0.1
username=admin
password=admin
sed -i "/^\[customize\]$/,/^\[/ s/^.*#picture_url =/picture_url =/" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#yourportal.ddns.net#$url#" zmeventnotification.ini 
sed -i "/^\[customize\]$/,/^\[/ s#^.*picture_portal_username=.*#picture_portal_username=$username#" zmeventnotification.ini
sed -i "/^\[customize\]$/,/^\[/ s#^.*picture_portal_password=.*#picture_portal_password=$password#" zmeventnotification.ini

# Hook
sed -i "/^\[hook\]$/,/^\[/ s#^.*hook_script =.*#hook_script = '/usr/bin/detect_wrapper.sh'#" zmeventnotification.ini
sed -i "/^\[hook\]$/,/^\[/ s#^.*use_hook_description =.*#use_hook_description = yes#" zmeventnotification.ini
sed -i "/^\[hook\]$/,/^\[/ s#^.*hook_pass_image_path =.*#hook_pass_image_path = yes#" zmeventnotification.ini 


# Installation de l'Event Server
# ------------------------------
apt install -y gcc make cmake perl libcrypt-mysql-perl libcrypt-eksblowfish-perl libmodule-build-perl python python3-pip libyaml-perl libjson-perl

export PERL_MM_USE_DEFAULT=1
perl -MCPAN -e "install CPAN"  # need yes
perl -MCPAN -e "install Crypt::MySQL"
perl -MCPAN -e "install Config::IniFiles"sudo perl -MCPAN -e "install Crypt::Eksblowfish::Bcrypt"
perl -MCPAN -e "install Net::WebSocket::Server"
perl -MCPAN -e "install LWP::Protocol::https"
perl -MCPAN -e "install Net::MQTT::Simple"
perl -MCPAN -e "install Getopt::Long"

chmod a+x /usr/bin/zmeventnotification/zmeventnotification.pl

cd /usr/bin/zmeventnotification/
#sed -i "s/INTERACTIVE='yes'/INTERACTIVE='no'/g" install.sh
./install.sh --no-interactive --install-es --install-hook --install-config


# Installation de la partie reconnaissance
# ----------------------------------------
apt install -y libopenblas-dev liblapack-dev libblas-dev
pip3 install opencv_contrib_python
pip3 install future
pip3 install numpy
pip3 install requests
pip3 install Shapely
pip3 install imutils

pip3 install face_recognition














# Show IP
ip=$(hostname -I)
echo " >>>>  Please open https://${ip} (login=admin, pass=admin) <<<<"


