#!/bin/bash
## Install and configure the neutron network service
## Run this on the stack controller node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# this expects to run on a network node
if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi


# install neutron components
apt-get -y install \
  neutron-server neutron-plugin-ml2


# create the database
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE neutron;"
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${MYSQL_NEUTRON_PASS}';"
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${MYSQL_NEUTRON_PASS}';"


# conf files common to controller and compute nodes
source ${BASH_SOURCE%/*}/../files/neutron_conf.sh

# rm the service_provider block and replace
sed -i '/\[service_providers\]/,/^$/d' /etc/neutron/neutron.conf
cat >> /etc/neutron/neutron.conf <<SERV

[service_providers]
service_provider=LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default
service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default

SERV

source ${BASH_SOURCE%/*}/../files/ml2_conf_ini.sh

# populate the db
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron

# restart 'em all
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh neutron

