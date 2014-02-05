#!/bin/bash
## Install and configure the controller services for nova

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh


# this to check we are on the controller
if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

# nova requirements, and cinder client too
apt-get install -y \
  rabbitmq-server \
  dnsmasq \
  ntp \
  nova-api \
  nova-conductor \
  nova-scheduler \
  nova-objectstore \
  nova-cert \
  python-cinderclient

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE nova;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"

# write out nova.conf
source ${BASH_SOURCE%/*}/../files/nova_conf.sh

# populate the db
nova-manage db sync

# create the network
nova-manage network create private \
  --fixed_range_v4=${NOVA_FIXED_RANGE} \
  --network_size=64 \
  --bridge=br100 \
  --bridge_interface=${PRIVATE_INTERFACE}
nova-manage floating create --ip_range=${NOVA_FLOATING_RANGE}

# write out nova api-paste.ini for keystone
source ${BASH_SOURCE%/*}/../files/nova_api_paste_ini.sh

# restart 'em all
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova

nova net-list
nova-manage service list

# we should have a 'default' security group
# add SSH access and ping
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-list
nova secgroup-list-rules default

# create a keypair for the vagrant user as the non-admin user
OS_USERNAME=$DEMO_USERNAME nova keypair-add vagrant > ~vagrant/.ssh/vagrant.pem
chmod 0600 ~vagrant/.ssh/vagrant.pem
chown vagrant:vagrant ~vagrant/.ssh/vagrant.pem
nova keypair-list

# get a stackrc
source ${BASH_SOURCE%/*}/../tools/stackrc_write.sh

