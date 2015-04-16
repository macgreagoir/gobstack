#!/bin/bash
## nova controller and compute installers use this to write out nova.conf

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [ -z "`grep ^#gobstack /etc/nova/nova.conf`" ]; then
  cp /etc/nova/nova.conf /etc/nova/nova.conf.default
fi

cat > /etc/nova/nova.conf <<NOVA
#gobstack
[DEFAULT]
# api
enabled_apis = ec2,osapi_compute,metadata

# auth
auth_strategy = keystone

# common
lock_path = /var/lock/nova
root_helper = sudo nova-rootwrap /etc/nova/rootwrap.conf
state_path = /var/lib/nova
my_ip = ${PUBLIC_IP}

# ec2
ec2_dmz_host = ${CONTROLLER_PUBLIC_IP}
ec2_host = ${CONTROLLER_PUBLIC_IP}
ec2_private_dns_show_ip = True
keystone_ec2_url = http://${CONTROLLER_PUBLIC_IP}:5000/v2.0/ec2tokens

# hypervisor
connection_type = libvirt
libvirt_type = qemu
libvirt_use_virtio_for_bridges = True

# logging
logdir = /var/log/nova
verbose = True

# network
dhcpbridge_flagfile = /etc/nova/nova.conf
dhcpbridge = /usr/bin/nova-dhcpbridge
force_dhcp_release = True
network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver

# object storage
iscsi_helper = tgtadm
iscsi_ip_address = ${STORAGE_PRIVATE_IP}

# rabbitmq
rpc_backend = rabbit
rabbit_host = ${CONTROLLER_PUBLIC_IP}
rabbit_password = guest

# scheduling
scheduler_default_filter = AllHostsFilter

# volumes
volume_api_class = nova.volume.cinder.API
volume_driver = nova.volume.driver.ISCSIDriver
volumes_path = /var/lib/nova/volumes

# wsgi
api_paste_config = /etc/nova/api-paste.ini

[database]
connection = mysql://nova:${MYSQL_NOVA_PASS}@${CONTROLLER_PUBLIC_IP}/nova

[keystone_authtoken]
auth_uri = http://${CONTROLLER_PUBLIC_IP}:5000/v2.0
identity_uri = http://${CONTROLLER_PUBLIC_IP}:35357
admin_tenant_name = service
admin_user = nova
admin_password = nova

[glance]
host = ${CONTROLLER_PUBLIC_IP}

[neutron]
url = http://${CONTROLLER_PUBLIC_IP}:9696
auth_strategy = keystone
admin_tenant_name = service
admin_username = neutron
admin_password = neutron
admin_auth_url = http://${CONTROLLER_PUBLIC_IP}:35357/v2.0
service_metadata_proxy = true
metadata_proxy_shared_secret = ${NEUTRON_METADATA_PASS}

NOVA
