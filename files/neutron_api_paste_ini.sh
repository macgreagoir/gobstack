#!/bin/bash
## update /etc/neutron/api-paste.ini
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

# rm the filter:authtoken block and replace
sed -i '/\[filter:authtoken\]/,/^$/d' /etc/neutron/api-paste.ini
cat >> /etc/neutron/api-paste.ini <<API

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = ${CONTROLLER_PUBLIC_IP}
auth_port = 35357
auth_protocol = http
auth_uri = http://${CONTROLLER_PUBLIC_IP}:5000
admin_tenant_name = service
admin_user = neutron
admin_password = neutron

API

