#!/bin/bash
## Install and configure the controller services for nova

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# this to check we are on the controller
if [[ -z $(ip addr | grep "${CONTROLLER_PUBLIC_IP}") ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

# nova requirements; nova-cert and nova-consoleauth removed in modern Nova
apt-get install -y \
  rabbitmq-server \
  dnsmasq-base \
  nova-api \
  nova-conductor \
  nova-novncproxy \
  nova-scheduler \
  python3-novaclient

# create a dedicated rabbitmq user for OpenStack
rabbitmqctl add_user openstack openstack || true
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
service rabbitmq-server restart

# nova needs three databases in modern OpenStack
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE IF NOT EXISTS nova_api;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE IF NOT EXISTS nova;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE IF NOT EXISTS nova_cell0;"
for db in nova_api nova nova_cell0; do
  mysql -uroot -p${MYSQL_ROOT_PASS} -e \
    "GRANT ALL ON ${db}.* TO 'nova'@'%' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"
  mysql -uroot -p${MYSQL_ROOT_PASS} -e \
    "GRANT ALL ON ${db}.* TO 'nova'@'localhost' IDENTIFIED BY '${MYSQL_NOVA_PASS}';"
done
rm -f /var/lib/nova/nova.sqlite

# write out nova.conf
source ${BASH_SOURCE%/*}/../files/nova_conf.sh

# tweak for controller VNC
sed -i "/^\[vnc\]/,/^\[/ {
  /server_listen/ s/.*/server_listen = ${PUBLIC_IP}/
  /server_proxyclient_address/ s/.*/server_proxyclient_address = ${PUBLIC_IP}/
}" /etc/nova/nova.conf

# populate the databases (order matters)
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova

nova-manage cell_v2 list_cells

# restart services
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova

# add ping and ssh access to the default security group
openstack security group rule create --proto icmp --remote-ip 0.0.0.0/0 default
openstack security group rule create --proto tcp --dst-port 22 --remote-ip 0.0.0.0/0 default

nova-manage service list

# create a keypair for the vagrant user as the non-admin user
OS_PROJECT_NAME=${DEMO_TENANT_NAME} OS_USERNAME=${DEMO_USERNAME} \
  openstack keypair create vagrant > ~vagrant/.ssh/vagrant.pem
chmod 0600 ~vagrant/.ssh/vagrant.pem
chown vagrant:vagrant ~vagrant/.ssh/vagrant.pem

OS_PROJECT_NAME=${DEMO_TENANT_NAME} OS_USERNAME=${DEMO_USERNAME} \
  openstack keypair list

# get a stackrc
source ${BASH_SOURCE%/*}/../tools/stackrc_write.sh
