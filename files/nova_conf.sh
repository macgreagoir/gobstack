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
# metadata and compute APIs only; EC2 compat removed in modern Nova
enabled_apis = osapi_compute,metadata

auth_strategy = keystone

lock_path = /var/lock/nova
state_path = /var/lib/nova
my_ip = ${PUBLIC_IP}

transport_url = rabbit://openstack:openstack@${CONTROLLER_PUBLIC_IP}

# neutron networking
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver

# logging
log_dir = /var/log/nova

[api]
auth_strategy = keystone

[api_database]
connection = mysql+pymysql://nova:${MYSQL_NOVA_PASS}@${CONTROLLER_PUBLIC_IP}/nova_api

[database]
connection = mysql+pymysql://nova:${MYSQL_NOVA_PASS}@${CONTROLLER_PUBLIC_IP}/nova

[keystone_authtoken]
www_authenticate_uri = http://${CONTROLLER_PUBLIC_IP}:5000
auth_url = http://${CONTROLLER_PUBLIC_IP}:5000
memcached_servers = ${CONTROLLER_PUBLIC_IP}:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = nova

[glance]
api_servers = http://${CONTROLLER_PUBLIC_IP}:9292

[neutron]
auth_url = http://${CONTROLLER_PUBLIC_IP}:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = neutron
password = neutron
service_metadata_proxy = true
metadata_proxy_shared_secret = ${NEUTRON_METADATA_PASS}

[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://${CONTROLLER_PUBLIC_IP}:5000/v3
username = placement
password = placement

[libvirt]
virt_type = qemu

[vnc]
enabled = true
server_listen = ${PUBLIC_IP}
server_proxyclient_address = ${PUBLIC_IP}

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

NOVA
