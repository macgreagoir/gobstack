#!/bin/bash
## update /etc/neutron/neutron.conf
## run on controller, network central and each compute node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if [ ! -d /etc/neutron ]; then
  echo "Neutron packages need installed first" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

SERVICE_TENANT_ID=`keystone tenant-list | awk '/service/ {print $2}'`

if [ -z "`grep ^#gobstack /etc/neutron/neutron.conf`" ]; then
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

notification_driver = neutron.openstack.common.notifier.rpc_notifier

rpc_backend = neutron.openstack.common.rpc.impl_kombu
rabbit_host = ${CONTROLLER_PUBLIC_IP}
rabbit_password = guest

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
nova_url = http://${CONTROLLER_PUBLIC_IP}:8774/v2
nova_admin_username = nova
nova_admin_tenant_id = ${SERVICE_TENANT_ID}
nova_admin_password = nova
nova_admin_auth_url = http://${CONTROLLER_PUBLIC_IP}:35357/v2.0

[quotas]

[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://${CONTROLLER_PUBLIC_IP}:5000
auth_host = ${CONTROLLER_PUBLIC_IP}
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = neutron
admin_password = neutron
signing_dir = \$state_path/keystone-signing

[database]
connection = mysql://neutron:${MYSQL_NEUTRON_PASS}@${CONTROLLER_PUBLIC_IP}:3306/neutron

[service_providers]

NCONF
