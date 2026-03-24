#!/bin/bash
## update /etc/neutron/neutron.conf
## run on controller, network node and each compute node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if [ ! -d /etc/neutron ]; then
  echo "Neutron packages need installed first" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

SERVICE_PROJECT_ID=$(openstack project show service -f value -c id)

if [ -z "$(grep ^#gobstack /etc/neutron/neutron.conf)" ]; then
  cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.default
fi

cat > /etc/neutron/neutron.conf <<NCONF
#gobstack
[DEFAULT]
verbose = True
state_path = /var/lib/neutron
lock_path = \$state_path/lock

core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

auth_strategy = keystone

transport_url = rabbit://openstack:openstack@${CONTROLLER_PUBLIC_IP}

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True

[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
www_authenticate_uri = http://${CONTROLLER_PUBLIC_IP}:5000
auth_url = http://${CONTROLLER_PUBLIC_IP}:5000
memcached_servers = ${CONTROLLER_PUBLIC_IP}:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = neutron

[database]
connection = mysql+pymysql://neutron:${MYSQL_NEUTRON_PASS}@${CONTROLLER_PUBLIC_IP}:3306/neutron

[nova]
auth_url = http://${CONTROLLER_PUBLIC_IP}:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = nova
password = nova

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp

NCONF
