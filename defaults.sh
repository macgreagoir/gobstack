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

PUBLIC_INTERFACE=$(ip -o addr show | awk '/172\.16\.0/ {split($2,a,"@"); print a[1]}' | head -1)
PUBLIC_IP=$(ip -o addr show dev ${PUBLIC_INTERFACE} 2>/dev/null | awk '/inet / {split($4,a,"/"); print a[1]}' | head -1)

PRIVATE_INTERFACE=$(ip -o addr show | awk '/10\.0\.0/ {split($2,a,"@"); print a[1]}' | head -1)
PRIVATE_IP=$(ip -o addr show dev ${PRIVATE_INTERFACE} 2>/dev/null | awk '/inet / {split($4,a,"/"); print a[1]}' | head -1)

MYSQL_ROOT_PASS=openstack
MYSQL_CINDER_PASS=openstack
MYSQL_GLANCE_PASS=openstack
MYSQL_KEYSTONE_PASS=openstack
MYSQL_NEUTRON_PASS=openstack
MYSQL_NOVA_PASS=openstack
MYSQL_PLACEMENT_PASS=openstack

NEUTRON_METADATA_PASS=openstack

# DEMO meaning our example tenant, and non-admin user
# These are used throughout, so don't change them after bootstrapping
DEMO_TENANT_NAME=demo
DEMO_TENANT_DESC="Demo Tenant"
DEMO_USERNAME=demo
DEMO_PASSWORD=openstack

# standard env vars used by openstack cli tools (Keystone v3)
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://${CONTROLLER_PUBLIC_IP}:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_NO_CACHE=1
