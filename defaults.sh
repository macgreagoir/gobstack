#!/bin/bash
## centralise some useful vars

# based on Vagrantfile net config
CONTROLLER_PUBLIC_IP=172.20.0.100
PUBLIC_INTERFACE=`/sbin/ifconfig | awk '/172\.20\.0/ {print x}{x = $1}' | head -1`
PRIVATE_INTERFACE=`/sbin/ifconfig | awk '/10\.20\.0/ {print x}{x = $1}' | head -1`
NOVA_FIXED_RANGE="10.30.0.0/24"
NOVA_FLOATING_RANGE="172.20.10.0/24"

MYSQL_ROOT_PASS=openstack
MYSQL_KEYSTONE_PASS=openstack
MYSQL_GLANCE_PASS=openstack
MYSQL_NOVA_PASS=openstack

export OS_SERVICE_TOKEN=ADMIN
export OS_SERVICE_ENDPOINT=http://${CONTROLLER_PUBLIC_IP}:35357/v2.0

export OS_TENANT_NAME=demo
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://${CONTROLLER_PUBLIC_IP}:5000/v2.0
export OS_NO_CACHE=1

echo "Using controller at ${CONTROLLER_PUBLIC_IP} on ${PUBLIC_INTERFACE}"
