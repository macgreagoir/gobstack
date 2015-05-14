#!/bin/bash
## centralise some useful vars

# based on Vagrantfile net config
# 172.16.0.0/24 control plane public/mgmt
# 10.0.0.0/24 control plane private/data
# 172.16.1.0/24 cloud public/floating
# 10.0.1.0/24 cloud private/fixed
PUBLIC_RANGE="172.16.0.0/24"
CONTROLLER_PUBLIC_IP=172.16.0.100
NETWORK_PUBLIC_IP=172.16.0.120
NETWORK_FLOATING_IP=172.16.1.120
STORAGE_PUBLIC_IP=172.16.0.150
STORAGE_PRIVATE_IP=10.0.0.150

#NEUTRON
DEMO_TENANT_FIXED_RANGE="10.0.1.0/24"
DEMO_TENANT_FIXED_GW=10.0.1.1
FLOATING_RANGE="172.16.1.0/24"
FLOATING_START=172.16.1.2
FLOATING_END=172.16.1.119
FLOATING_GW=172.16.1.1

PUBLIC_INTERFACE=`/sbin/ifconfig | awk '/172\.16\.0/ {print x}{x = $1}' | head -1`
PUBLIC_IP=`ip a s ${PUBLIC_INTERFACE} | awk '/inet\ / {print $2}' | cut -d\/ -f 1`

PRIVATE_INTERFACE=`/sbin/ifconfig | awk '/10\.0\.0/ {print x}{x = $1}' | head -1`
PRIVATE_IP=`ip a s ${PRIVATE_INTERFACE} | awk '/inet\ / {print $2}' | cut -d\/ -f 1`

MYSQL_ROOT_PASS=openstack
MYSQL_CINDER_PASS=openstack
MYSQL_GLANCE_PASS=openstack
MYSQL_KEYSTONE_PASS=openstack
MYSQL_NEUTRON_PASS=openstack
MYSQL_NOVA_PASS=openstack

NEUTRON_METADATA_PASS=openstack

# DEMO meaning our example tenant, and non-admin user
# These are used throughout, so don't change them after bootstrapping
DEMO_TENANT_NAME=demo
DEMO_TENANT_DESC="Demo Tenant"
DEMO_USERNAME=demo
DEMO_PASSWORD=openstack

# standard env vars used by openstack cli tools
export OS_SERVICE_TOKEN=ADMIN
export OS_SERVICE_ENDPOINT=http://${CONTROLLER_PUBLIC_IP}:35357/v2.0

export OS_TENANT_NAME=${DEMO_TENANT_NAME}
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://${CONTROLLER_PUBLIC_IP}:5000/v2.0
export OS_NO_CACHE=1

