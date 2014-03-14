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
  neutron-server neutron-plugin-openvswitch


# create the database
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE neutron;"
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${MYSQL_NEUTRON_PASS}';"
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${MYSQL_NEUTRON_PASS}';"


# conf files common to controller and compute nodes too
source ${BASH_SOURCE%/*}/../files/neutron_conf.sh
source ${BASH_SOURCE%/*}/../files/neutron_api_paste_ini.sh
source ${BASH_SOURCE%/*}/../files/ovs_neutron_plugin_ini.sh

source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh neutron

