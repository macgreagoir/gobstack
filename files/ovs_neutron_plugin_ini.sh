#!/bin/bash
## Update /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
## Run this on the controller, network and compute nodes

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# TODO controller may not want br-int, br-tun or local_ip
sed -i \
  -e 's/^# Example: \(tenant_network_type = gre\)/\1/' \
  -e '0,/^# tunnel_id_ranges =/s//tunnel_id_ranges = 1:1000/' \
  -e 's/# \(enable_tunneling = \)False/\1True/' \
  -e '0,/# \(integration_bridge = br-int\)/s//\1/' \
  -e '0,/# \(tunnel_bridge = br-tun\)/s//\1/' \
  -e "0,/# local_ip =/s//local_ip = ${PRIVATE_INTERFACE}/" \
  -e 's/^# \(firewall_driver = neutron.agent.firewall.NoopFirewallDriver\)/\1/' \
  /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

