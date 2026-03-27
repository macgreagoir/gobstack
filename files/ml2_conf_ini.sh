#!/bin/bash
## Run this on the controller, network and compute nodes

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [ -z "$(grep ^#gobstack /etc/neutron/plugins/ml2/ml2_conf.ini)" ]; then
  cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.default
fi

cat > /etc/neutron/plugins/ml2/ml2_conf.ini <<ML2
#gobstack
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = openvswitch,l2population

[ml2_type_flat]
flat_networks = provider

[ml2_type_vlan]

[ml2_type_vxlan]
vni_ranges = 1:1000

[securitygroup]
enable_ipset = True

ML2

# In Dalmatian the OVS agent reads openvswitch_agent.ini, not ml2_conf.ini
if [ -f /etc/neutron/plugins/ml2/openvswitch_agent.ini ]; then
  if [ -z "$(grep ^#gobstack /etc/neutron/plugins/ml2/openvswitch_agent.ini)" ]; then
    cp /etc/neutron/plugins/ml2/openvswitch_agent.ini \
       /etc/neutron/plugins/ml2/openvswitch_agent.ini.default
  fi
  cat > /etc/neutron/plugins/ml2/openvswitch_agent.ini <<OVS
#gobstack
[ovs]
local_ip = ${PRIVATE_IP}
bridge_mappings = provider:br-ex

[agent]
tunnel_types = vxlan
l2_population = True

[securitygroup]
enable_ipset = True

OVS
fi
