#!/bin/bash
## Run this on the controller, network and compute nodes

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [ -z "`grep ^#openstack_demo /etc/neutron/plugins/ml2/ml2_conf.ini`" ]; then
  cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.default
fi

cat > /etc/neutron/plugins/ml2/ml2_conf.ini <<ML2
#openstack_demo
[ml2]
type_drivers = gre
tenant_network_types = gre
mechanism_drivers = openvswitch

[ml2_type_flat]

[ml2_type_vlan]

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
enable_security_group = True

ML2
