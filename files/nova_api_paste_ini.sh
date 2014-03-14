#!/bin/bash
## Write out the nova/api-paste.ini to use keystone

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# rm the filter:authtoken block and replace
sed -i '/\[filter\:authtoken\]/,/^$/d' /etc/nova/api-paste.ini

cat >> /etc/nova/api-paste.ini <<APIP

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
admin_tenant_name = service
admin_user = nova
admin_password = nova
auth_host = ${CONTROLLER_PUBLIC_IP}
auth_port = 35357
auth_protocol = http
auth_uri = http://${CONTROLLER_PUBLIC_IP}:5000/
service_host = ${CONTROLLER_PUBLIC_IP}
service_port = 5000
service_protocol = http

APIP

