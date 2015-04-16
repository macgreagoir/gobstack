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
  dnsmasq-base \
  nova-api \
  nova-cert \
  nova-conductor \
  nova-consoleauth \
  nova-novncproxy \
  nova-scheduler \
  python-novaclient

# just to be sure
rabbitmqctl change_password guest guest
service rabbitmq-server restart

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE nova;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"
rm -f /var/lib/nova/nova.sqlite

# write out nova.conf
source ${BASH_SOURCE%/*}/../files/nova_conf.sh

# ...and tweak it a wee bit
sed -i "/^my_ip.*/ a\
vncserver_listen = ${PUBLIC_IP}\nvncserver_proxyclient_address = ${PUBLIC_IP}" /etc/nova/nova.conf

# populate the db
su -s /bin/sh -c "nova-manage db sync" nova

# restart 'em all
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova

# add ping and ssh access to the default security group
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

nova-manage service list

# create a keypair for the vagrant user as the non-admin user
OS_USERNAME=$DEMO_USERNAME nova keypair-add vagrant > ~vagrant/.ssh/vagrant.pem
chmod 0600 ~vagrant/.ssh/vagrant.pem
chown vagrant:vagrant ~vagrant/.ssh/vagrant.pem
OS_USERNAME=$DEMO_USERNAME nova keypair-list

# get a stackrc
source ${BASH_SOURCE%/*}/../tools/stackrc_write.sh

