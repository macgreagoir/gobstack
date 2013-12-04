#!/bin/bash
## Install and configure the controller services for nova

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/defaults.sh


# this to check we are on the controller
if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

apt-get install -y \
  rabbitmq-server \
  dnsmasq \
  ntp \
  nova-api \
  nova-conductor \
  nova-scheduler \
  nova-objectstore \
  nova-cert

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE nova;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"

# write out nova.conf
source ${BASH_SOURCE%/*}/nova_conf.sh

# populate the db
nova-manage db sync

# create the network
nova-manage network create private \
  --fixed_range_v4=${NOVA_FIXED_RANGE} \
  --network_size=64 \
  --bridge_interface=${PRIVATE_INTERFACE}
nova-manage floating create --ip_range=${NOVA_FLOATING_RANGE}

# write out nova api-paste.ini for keystone
source ${BASH_SOURCE%/*}/nova_api_paste_ini.sh

sleep 3
nova net-list
nova-manage service list
