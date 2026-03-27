#!/bin/bash
## Install and configure a nova compute node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# use nova-compute with qemu to avoid kvm inside a VM
apt-get install -y \
  ipset \
  nova-compute \
  neutron-common \
  neutron-plugin-ml2 \
  neutron-openvswitch-agent \
  linux-headers-$(uname -r)

# configure nova-compute for qemu (no hardware virtualisation in a VM)
cat > /etc/nova/nova-compute.conf <<NCOMP
[DEFAULT]
compute_driver = libvirt.LibvirtDriver

[libvirt]
virt_type = qemu
NCOMP

# let it route and disable packet destination filtering
sed -i \
  -e 's/#net.ipv4.conf.all.rp_filter=.*/net.ipv4.conf.all.rp_filter=0/' \
  -e 's/#net.ipv4.conf.default.rp_filter=.*/net.ipv4.conf.default.rp_filter=0/' \
  -e 's/#net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' \
  /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# for neutron
service openvswitch-switch restart
ovs-vsctl add-br br-int || true
ovs-vsctl add-br br-ex || true

# write out nova.conf
source ${BASH_SOURCE%/*}/../files/nova_conf.sh

# tweak for compute VNC
sed -i "/^\[vnc\]/,/^\[/ {
  /server_listen/ s/.*/server_listen = 0.0.0.0/
  /server_proxyclient_address/ s/.*/server_proxyclient_address = ${PUBLIC_IP}/
  /novncproxy_base_url/ s|.*|novncproxy_base_url = http://${CONTROLLER_PUBLIC_IP}:6080/vnc_lite.html|
}" /etc/nova/nova.conf

# for safety
rm -f /var/lib/nova/nova.sqlite

# write out the neutron confs
source ${BASH_SOURCE%/*}/../files/neutron_conf.sh
source ${BASH_SOURCE%/*}/../files/ml2_conf_ini.sh

# restart services
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh neutron
