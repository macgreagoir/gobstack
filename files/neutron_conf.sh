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

# NOTE core_plugin should be configured by default:
# core_plugin = neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2
sed -i \
  -e 's/# \(auth_strategy = keystone\)/\1/' \
  -e "s/^auth_host =.*/auth_host = ${CONTROLLER_PUBLIC_IP}/" \
  -e 's/%SERVICE_TENANT_NAME%/service/' \
  -e 's/%SERVICE_USER%/neutron/' \
  -e 's/%SERVICE_PASSWORD%/neutron/' \
  -e 's/# \(rpc_backend = neutron.openstack.common.rpc.impl_kombu\)/\1/' \
  -e "s/# rabbit_host = localhost/rabbit_host = ${CONTROLLER_PUBLIC_IP}/" \
  -e 's/# \(rabbit_port = 5672\)/\1/' \
  -e "s|# connection = .*|connection = mysql://neutron:${MYSQL_NEUTRON_PASS}@${CONTROLLER_PUBLIC_IP}:3306/neutron|" \
  -e 's/\(connection = sqlite.*\)/# \1/' \
  /etc/neutron/neutron.conf

