#!/bin/bash
## centralise some useful vars

# based on Vagrantfile net config
# 172.16.0.0/24 control plane public/mgmt
# 10.0.0.0/24 control plane private/data
# 172.16.1.0/24 cloud public/floating
# 10.0.1.0/24 cloud private/fixed
CONTROLLER_PUBLIC_IP=172.16.0.100
NETWORK_PUBLIC_IP=172.16.0.120
STORAGE_PUBLIC_IP=172.16.0.150
STORAGE_PRIVATE_IP=10.0.0.150
PUBLIC_INTERFACE=`/sbin/ifconfig | awk '/172\.16\.0/ {print x}{x = $1}' | head -1`
PRIVATE_INTERFACE=`/sbin/ifconfig | awk '/10\.0\.0/ {print x}{x = $1}' | head -1`
NEUTRON_FIXED_RANGE="10.0.1.0/24"
NEUTRON_FLOATING_RANGE="172.16.1.0/24"

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

