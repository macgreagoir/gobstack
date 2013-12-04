#!/bin/bash
## nova controller and compute installers use this to write out nova.conf

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/defaults.sh

cat > /etc/nova/nova.conf <<NOVA
[DEFAULT]
# api
enabled_apis=ec2,osapi_compute,metadata

# auth
auth_strategy=keystone

# common
lock_path=/var/lock/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
state_path=/var/lib/nova

# db
sql_connection=mysql://nova:${MYSQL_NOVA_PASS}@${CONTROLLER_PUBLIC_IP}/nova

# ec2
ec2_dmz_host=${CONTROLLER_PUBLIC_IP}
ec2_host=${CONTROLLER_PUBLIC_IP}
ec2_private_dns_show_ip=True
keystone_ec2_url=http://${CONTROLLER_PUBLIC_IP}:5000/v2.0/ec2tokens

# glance
image_service=nova.image.glance.GlanceImageService
glance_api_servers=${CONTROLLER_PUBLIC_IP}:9292

# hypervisor
connection_type=libvirt
libvirt_type=qemu
libvirt_use_virtio_for_bridges=True

# logging
logdir=/var/log/nova
verbose=True

# network
auto_assign_floating_ip=True
dhcpbridge=/usr/bin/nova-dhcpbridge
dhcpbridge_flagfile=/etc/nova/nova.conf
force_dhcp_release=True
public_interface=${PUBLIC_INTERFACE}

# object storage
iscsi_helper=tgtadm

# rabbitmq
rabbit_host=${CONTROLLER_PUBLIC_IP}

# scheduling
scheduler_default_filter=AllHostsFilter

# volumes
volumes_path=/var/lib/nova/volumes

# wsgi
api_paste_config=/etc/nova/api-paste.ini

NOVA
