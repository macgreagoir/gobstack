#!/bin/bash
## Install and configure a nova compute node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# spits out junk to the console
echo 'apt-get install -y python-guestfs' | at now +3 minutes

# use nova-compute-qemu to avoid kvm inside a VM
apt-get install -y \
  ipset \
  nova-compute-qemu \
  neutron-common \
  neutron-plugin-ml2 \
  neutron-plugin-openvswitch-agent \
  linux-headers-`uname -r` \
  openvswitch-datapath-dkms

# make the kernel readable by normal users for qemu and libguestfs
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/759725
dpkg-statoverride  --update --add root root 0644 /boot/vmlinuz-$(uname -r)
cat > /etc/kernel/postinst.d/statoverride <<SOVR
#!/bin/sh
version="$1"
# passing the kernel version is required
[ -z "${version}" ] && exit 0
dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-${version}
SOVR
chmod +x /etc/kernel/postinst.d/statoverride

# let it route and disable packet destination filtering
sed -i \
  -e 's/#net.ipv4.conf.all.rp_filter=.*/net.ipv4.conf.all.rp_filter=0/' \
  -e 's/#net.ipv4.conf.default.rp_filter=.*/net.ipv4.conf.default.rp_filter=0/' \
  -e 's/#net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' \
  /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# for neutron, including flat network on br-ex
service openvswitch-switch restart

## adjust networking here, not in /etc/network/interfaces, to keep Vagrant happy
ip a del ${PUBLIC_IP}/24 dev eth1
ip r del ${PUBLIC_RANGE} dev eth1

ovs-vsctl add-br br-int
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex eth1

# as per the Vagrantfile
# TODO fix hardcoded netmask
ip a add ${PUBLIC_IP}/24 dev br-ex
ip l set dev br-ex up
ip l set dev br-ex promisc on

/etc/init.d/networking restart

# config bridge on reboot
cat > /etc/init.d/br-ex <<BREX
#!/bin/bash
## run from /etc/rc.local

ip a del ${PUBLIC_IP}/24 dev eth1 || true
ip r del ${PUBLIC_RANGE} dev eth1 || true
ip a add ${PUBLIC_IP}/24 dev br-ex || true
ip l set dev br-ex up
ip l set dev br-ex promisc on
/etc/init.d/networking restart
/vagrant/tools/daemons_restart.sh nova
/vagrant/tools/daemons_restart.sh neutron

BREX
chmod +x /etc/init.d/br-ex

# TODO rc.local isn't running at boot
if [ -z "`grep '\/etc\/init\.d\/br\-eth1' /etc/rc.local`" ]; then
  sed -i '/^exit 0/ i\
/etc/init.d/br-ex\n' /etc/rc.local
fi

# write out nova.conf
source ${BASH_SOURCE%/*}/../files/nova_conf.sh

# ...and tweak it a wee bit
sed -i "/^my_ip.*/ a\
vnc_enabled = True\nvncserver_listen = 0.0.0.0\nvncserver_proxyclient_address = ${PUBLIC_IP}\nnovncproxy_base_url = http://${CONTROLLER_PUBLIC_IP}:6080/vnc_auto.html" /etc/nova/nova.conf

# for safety
rm -f /var/lib/nova/nova.sqlite

# write out the neutron confs
source ${BASH_SOURCE%/*}/../files/neutron_conf.sh
source ${BASH_SOURCE%/*}/../files/ml2_conf_ini.sh

# restart 'em all
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh neutron

