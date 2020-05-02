#!/bin/bash
set -e

arg1=$1
arg2=$2

sleep 2

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo " >>>> Installation de Zabbix <<<<"

# parameters
DB_USER=zabbix
DB_PASS=toto

# Install Zabbix
apt update
apt upgrade -y
apt install -y nano wget

source /etc/os-release
if [ "$VERSION_ID" == "10" ]; then
    wget https://repo.zabbix.com/zabbix/4.4/debian/pool/main/z/zabbix-release/zabbix-release_4.4-1+buster_all.deb
    dpkg -i zabbix-release_4.4-1+buster_all.deb
    rm -f zabbix-release_4.4-1+buster_all.deb
elif [ "$VERSION_ID" == "9" ]; then
    wget https://repo.zabbix.com/zabbix/4.4/debian/pool/main/z/zabbix-release/zabbix-release_4.4-1+stretch_all.deb
    dpkg -i zabbix-release_4.4-1+stretch_all.deb
    rm -f zabbix-release_4.4-1+stretch_all.deb
else
    echo"Error! Distribution not supported!"
    exit 1
fi

# Install Zabbix package
apt update
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent

# Configure MySQL
mysql -u root -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -u root -e "grant all privileges on zabbix.* to zabbix@localhost identified by '${DB_PASS}';"
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p${DB_PASS} zabbix

# Configure
sed -i "s/^.*DBPassword=.*/DBPassword=${DB_PASS}/g" /etc/zabbix/zabbix_server.conf
sed -i "s#^.*php_value date.timezone .*#        php_value date.timezone Europe/Paris#g" /etc/zabbix/apache.conf

# Configure
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2


# Show IP
ip=$(hostname -I)
echo " >>>>  InfluxDB installed on IP ${ip}  <<<<"

exit 0

# Configure
systemctl unmask influxdb.service
systemctl start influxdb
systemctl enable influxdb

systemctl stop influxdb
chown -R influxdb:influxdb /var/lib/influxdb
systemctl start influxdb
sleep 2
chown -R influxdb:influxdb /var/lib/influxdb
sleep 2

influx -execute "CREATE DATABASE ${INFLUXDB_USER}" ||
  influx -execute "CREATE DATABASE ${INFLUXDB_USER}" ||
    influx -execute "CREATE DATABASE ${INFLUXDB_USER}" ||
      exit 1

influx -execute "CREATE USER ${INFLUXDB_USER} WITH PASSWORD '${INFLUXDB_PASS}' WITH ALL PRIVILEGES" ||
  influx -execute "CREATE USER ${INFLUXDB_USER} WITH PASSWORD '${INFLUXDB_PASS}' WITH ALL PRIVILEGES" ||
    influx -execute "CREATE USER ${INFLUXDB_USER} WITH PASSWORD '${INFLUXDB_PASS}' WITH ALL PRIVILEGES" ||
      exit 1


# Show IP
ip=$(hostname -I)
echo " >>>>  InfluxDB installed on IP ${ip}  <<<<"
