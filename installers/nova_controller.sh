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
  python-novaclient \
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

# write out nova api-paste.ini for keystone
source ${BASH_SOURCE%/*}/../files/nova_api_paste_ini.sh

# restart 'em all
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova

nova-manage service list

# create a keypair for the vagrant user as the non-admin user
OS_USERNAME=$DEMO_USERNAME nova keypair-add vagrant > ~vagrant/.ssh/vagrant.pem
chmod 0600 ~vagrant/.ssh/vagrant.pem
chown vagrant:vagrant ~vagrant/.ssh/vagrant.pem
nova keypair-list

# get a stackrc
source ${BASH_SOURCE%/*}/../tools/stackrc_write.sh

