#!/bin/bash
## Run this on the controller, network and compute nodes

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [ -z "`grep ^#gobstack /etc/neutron/plugins/ml2/ml2_conf.ini`" ]; then
  cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.default
fi

cat > /etc/neutron/plugins/ml2/ml2_conf.ini <<ML2
#gobstack
[ml2]
type_drivers = vxlan,flat
tenant_network_types = vxlan,flat
mechanism_drivers = openvswitch

[ml2_type_flat]
flat_networks = physnet1

[ml2_type_vlan]

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]
vni_ranges = 1001:2000

[ovs]
local_ip = ${PRIVATE_IP}
enable_tunneling = True
tunnel_type = vxlan
bridge_mappings = physnet1:br-ex

[agent]
tunnel_types = vxlan

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
enable_security_group = True
enable_ipset = True

ML2
