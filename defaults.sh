#!/bin/bash
## centralise some useful vars

# based on Vagrantfile net config
CONTROLLER_PUBLIC_IP=172.16.0.100
STORAGE_PUBLIC_IP=172.16.0.150
STORAGE_PRIVATE_IP=10.20.0.150
PUBLIC_INTERFACE=`/sbin/ifconfig | awk '/172\.16\.0/ {print x}{x = $1}' | head -1`
PRIVATE_INTERFACE=`/sbin/ifconfig | awk '/10\.20\.0/ {print x}{x = $1}' | head -1`
NOVA_FIXED_RANGE="10.30.0.0/24"
NOVA_FLOATING_RANGE="172.16.10.0/24"

MYSQL_ROOT_PASS=openstack
MYSQL_KEYSTONE_PASS=openstack
MYSQL_GLANCE_PASS=openstack
MYSQL_NOVA_PASS=openstack
MYSQL_CINDER_PASS=openstack

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

