#!/bin/bash
## Install and configure a nova compute node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# use nova-compute-qemu to avoid kvm inside a VM
apt-get install -y \
  ntp \
  nova-compute \
  nova-api-metadata \
  nova-compute-qemu \
  neutron-plugin-openvswitch-agent \
  linux-headers-`uname -r` \
  openvswitch-datapath-dkms

# let it route and disable packet destination filtering
sed -i \
  -e 's/#net.ipv4.conf.all.rp_filter=.*/net.ipv4.conf.all.rp_filter=0/' \
  -e 's/#net.ipv4.conf.default.rp_filter=.*/net.ipv4.conf.default.rp_filter=0/' \
  -e 's/#net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' \
  /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# for neutron
service openvswitch-switch restart
ovs-vsctl add-br br-int

# write out nova.conf
source ${BASH_SOURCE%/*}/../files/nova_conf.sh

# write out nova api-paste.ini for keystone
source ${BASH_SOURCE%/*}/../files/nova_api_paste_ini.sh

# write out the neutron confs
source ${BASH_SOURCE%/*}/../files/neutron_conf.sh
source ${BASH_SOURCE%/*}/../files/ovs_neutron_plugin_ini.sh

# restart 'em all
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh neutron

