#!/bin/bash
## Create an external network and a tenant internal network and router

source ${BASH_SOURCE%/*}/../defaults.sh

# this to check we are on the controller
if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi


OS_TENANT_NAME=admin
DEMO_TENANT_ID=`keystone tenant-list | awk "/\ ${DEMO_TENANT_NAME}\ / {print \\$2}"`

# these are wrapped in if statements to avoid duplicates and errors, but
# really if any are skipped they all break for var dependencies

if [ `neutron net-list | grep -c 'ext-net'` -eq 0 ]; then
  neutron net-create ext-net --shared --router:external=True
fi

if [ `neutron subnet-list | grep -c "${FLOATING_RANGE}"` -eq 0 ]; then
  neutron subnet-create ext-net --name ext-subnet \
    --allocation-pool start=${FLOATING_START},end=${FLOATING_END} \
    --disable-dhcp --gateway ${FLOATING_GW} ${FLOATING_RANGE}
fi

if [ `neutron router-list | grep -c "${DEMO_TENANT_NAME}-router"` -eq 0 ]; then
  neutron router-create --tenant-id ${DEMO_TENANT_ID} ${DEMO_TENANT_NAME}-router
  neutron router-gateway-set ${DEMO_TENANT_NAME}-router ext-net

  # ext-subnet gateway is set, but this is a vbox host-only network, so instance
  # traffic won't really have a route out.
  # Work-around that to allow access to the floating IP range from this host.
  neutron router-update demo-router --routes type=dict list=true \
    destination=${PUBLIC_RANGE},nexthop=${NETWORK_PUBLIC_IP}
  ip r a ${FLOATING_RANGE} via ${NETWORK_FLOATING_IP}
fi

if [ `neutron net-list | grep -c ${DEMO_TENANT_NAME}-net` -eq 0 ]; then
  neutron net-create --tenant-id ${DEMO_TENANT_ID} ${DEMO_TENANT_NAME}-net

  neutron subnet-create ${DEMO_TENANT_NAME}-net --name ${DEMO_TENANT_NAME}-subnet --tenant-id ${DEMO_TENANT_ID} \
    --gateway ${DEMO_TENANT_FIXED_GW} ${DEMO_TENANT_FIXED_RANGE}

  neutron router-interface-add ${DEMO_TENANT_NAME}-router ${DEMO_TENANT_NAME}-subnet
fi

OS_TENANT_NAME=$DEMO_TENANT_NAME

for n in net subnet router; do neutron ${n}-list; done

