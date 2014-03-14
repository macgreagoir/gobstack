#!/bin/bash
## Create an external network and a tenant internal network and router

source ${BASH_SOURCE%/*}/../defaults.sh

OS_TENANT_NAME=admin
DEMO_TENANT_ID=`keystone tenant-list | awk "/\ ${DEMO_TENANT_NAME}\ / {print \\$2}"`

# these are wrapped in if statements to avoid duplicates and errors, but
# really if any are skipped they all break for var dependencies

if [ `neutron net-list | grep -c 'ext-net'` -eq 0 ]; then
  neutron net-create --router:external=true \
    --provider:network_type=gre --provider:segmentation_id=2 \
    ext-net
fi

if [ `neutron subnet-list | grep -c "${NEUTRON_FLOATING_RANGE}"` -eq 0 ]; then
  neutron subnet-create --disable-dhcp --name ext-subnet \
    ext-net ${NEUTRON_FLOATING_RANGE}
fi

if [ `neutron router-list | grep -c 'ext-to-int'` -eq 0 ]; then
  neutron router-create --tenant-id ${DEMO_TENANT_ID} ext-to-int
  neutron router-gateway-set ext-to-int ext-net
fi

if [ `neutron net-list | grep -c ${DEMO_TENANT_NAME}-net` -eq 0 ]; then
  neutron net-create --tenant-id ${DEMO_TENANT_ID} \
    --provider:network_type=gre --provider:segmentation_id=3 \
    ${DEMO_TENANT_NAME}-net

  neutron subnet-create --name ${DEMO_TENANT_NAME}-subnet --tenant-id ${DEMO_TENANT_ID} \
    ${DEMO_TENANT_NAME}-net ${NEUTRON_FIXED_RANGE}

  neutron router-interface-add ext-to-int ${DEMO_TENANT_NAME}-subnet
fi

OS_TENANT_NAME=$DEMO_TENANT_NAME

for n in net subnet router; do neutron ${n}-list; done

