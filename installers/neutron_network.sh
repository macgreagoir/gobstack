#!/bin/bash
## Install and configure the neutron network service
## Run this on the dedicated network node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# this expects to run on a network node
if [[ -z `ip addr | grep "${NETWORK_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${NETWORK_PUBLIC_IP}" 1>&2
  exit 1
fi


# install networking tools, neutron components
apt-get -y install \
  linux-headers-`uname -r` \
  bridge-utils \
  neutron-plugin-ml2 \
  neutron-plugin-openvswitch-agent \
  openvswitch-datapath-dkms \
  neutron-l3-agent \
  neutron-dhcp-agent

# enable packet forwarding and disable packet destination filtering
sed -i \
  -e 's/#net.ipv4.conf.all.rp_filter=.*/net.ipv4.conf.all.rp_filter=0/' \
  -e 's/#net.ipv4.conf.default.rp_filter=.*/net.ipv4.conf.default.rp_filter=0/' \
  -e 's/#net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' \
  /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

service openvswitch-switch restart

## adjust networking here, not in /etc/network/interfaces, to keep Vagrant happy
ip a del ${NETWORK_FLOATING_IP}/24 dev eth3

# create the standard internal and external bridges
ovs-vsctl add-br br-int
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex eth3
# as per the Vagrantfile
# TODO fix hardcoded netmask
ip a add ${NETWORK_FLOATING_IP}/24 dev br-ex
ip l set dev br-ex up
ip l set dev br-ex promisc on

service networking restart

# config bridge on reboot
cat > /etc/init.d/br-ex <<BREX
#!/bin/bash
## run from /etc/rc.local

ip a del ${NETWORK_FLOATING_IP}/24 dev eth3 || true
ip a add ${NETWORK_FLOATING_IP}/24 dev br-ex || true
ip l set dev br-ex promisc on
service networking restart
service openvswitch-switch restart
/vagrant/tools/daemons_restart.sh neutron

BREX
chmod +x /etc/init.d/br-ex

# TODO rc.local isn't running at boot
if [ -z "`grep '\/etc\/init\.d\/br\-ex' /etc/rc.local`" ]; then
  sed -i '/^exit 0/ i\
/etc/init.d/br-ex\n' /etc/rc.local
fi

# conf files common to controller and compute nodes too
source ${BASH_SOURCE%/*}/../files/neutron_conf.sh
source ${BASH_SOURCE%/*}/../files/ml2_conf_ini.sh

if [ -z "`grep '\[ovs\]' /etc/neutron/plugins/ml2/ml2_conf.ini`" ]; then
  cat >> /etc/neutron/plugins/ml2/ml2_conf.ini <<OVS

[ovs]
local_ip = ${PRIVATE_IP}
tunnel_type = gre
enable_tunneling = True

OVS
fi

sed -i \
  -e "s/localhost/${CONTROLLER_PUBLIC_IP}/" \
  -e 's/%SERVICE_TENANT_NAME%/service/' \
  -e 's/%SERVICE_USER%/neutron/' \
  -e 's/%SERVICE_PASSWORD%/neutron/' \
  -e "s/# nova_metadata_ip =.*/nova_metadata_ip = ${CONTROLLER_PUBLIC_IP}/" \
  -e "s/# metadata_proxy_shared_secret =.*/metadata_proxy_shared_secret = ${NEUTRON_METADATA_PASS}/" \
  /etc/neutron/metadata_agent.ini

sed -i \
  -e 's/# dhcp_driver =.*/dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq/' \
  -e 's/# \(interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver\)/\1/' \
  -e 's/# use_namespaces =.*/use_namespaces = True/' \
  /etc/neutron/dhcp_agent.ini

sed -i \
  -e 's/# \(interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver\)/\1/' \
  -e 's/# use_namespaces =.*/use_namespaces = True/' \
  /etc/neutron/l3_agent.ini

source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh neutron

# get a stackrc
source ${BASH_SOURCE%/*}/../tools/stackrc_write.sh

