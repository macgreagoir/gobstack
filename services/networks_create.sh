#!/bin/bash
## Create an external network and a tenant internal network and router

source ${BASH_SOURCE%/*}/../defaults.sh

# this to check we are on the controller
if [[ -z $(ip addr | grep "${CONTROLLER_PUBLIC_IP}") ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

OS_PROJECT_NAME=admin
DEMO_PROJECT_ID=$(openstack project show ${DEMO_TENANT_NAME} -f value -c id)

# these are wrapped in if statements to avoid duplicates and errors, but
# really if any are skipped they all break for var dependencies

if [ $(openstack network list -f value -c Name | grep -c '^ext-net$') -eq 0 ]; then
  openstack network create \
    --external \
    --provider-physical-network provider \
    --provider-network-type flat \
    ext-net
fi

if [ $(openstack subnet list -f value -c Network | grep -c "${FLOATING_RANGE}") -eq 0 ]; then
  openstack subnet create ext-subnet \
    --network ext-net \
    --allocation-pool start=${FLOATING_START},end=${FLOATING_END} \
    --no-dhcp \
    --gateway ${FLOATING_GW} \
    --subnet-range ${FLOATING_RANGE}
fi

if [ $(openstack router list -f value -c Name | grep -c "${DEMO_TENANT_NAME}-router") -eq 0 ]; then
  openstack router create --project ${DEMO_PROJECT_ID} ${DEMO_TENANT_NAME}-router
  openstack router set --external-gateway ext-net ${DEMO_TENANT_NAME}-router

  # ext-subnet gateway is set, but this is a vbox host-only network, so instance
  # traffic won't really have a route out.
  # Work-around that to allow access to the floating IP range from this host.
  openstack router set --route destination=${PUBLIC_RANGE},gateway=${NETWORK_PUBLIC_IP} \
    ${DEMO_TENANT_NAME}-router
  ip r a ${FLOATING_RANGE} via ${NETWORK_FLOATING_IP} 2>/dev/null || true
fi

if [ $(openstack network list -f value -c Name | grep -c "${DEMO_TENANT_NAME}-net") -eq 0 ]; then
  openstack network create --project ${DEMO_PROJECT_ID} ${DEMO_TENANT_NAME}-net

  openstack subnet create ${DEMO_TENANT_NAME}-subnet \
    --network ${DEMO_TENANT_NAME}-net \
    --project ${DEMO_PROJECT_ID} \
    --gateway ${DEMO_TENANT_FIXED_GW} \
    --subnet-range ${DEMO_TENANT_FIXED_RANGE}

  openstack router add subnet ${DEMO_TENANT_NAME}-router ${DEMO_TENANT_NAME}-subnet
fi

OS_PROJECT_NAME=${DEMO_TENANT_NAME}

for r in network subnet router; do openstack ${r} list; done
