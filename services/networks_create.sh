#!/bin/bash
## Create an external network and a tenant internal network and router

source ${BASH_SOURCE%/*}/../defaults.sh

# this to check we are on the network node, because we edit l3_agent.ini
if [[ -z `ip addr | grep "${NETWORK_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${NETWORK_PUBLIC_IP}" 1>&2
  exit 1
fi


OS_TENANT_NAME=admin
DEMO_TENANT_ID=`keystone tenant-list | awk "/\ ${DEMO_TENANT_NAME}\ / {print \\$2}"`

# these are wrapped in if statements to avoid duplicates and errors, but
# really if any are skipped they all break for var dependencies

# ext-net for the floating IPs
if [ `neutron net-list | grep -c 'ext-net'` -eq 0 ]; then
  neutron net-create ext-net --shared --router:external=True

  EXT_NET_ID=`neutron net-list | awk '/ext-net/ {print $2}'`
  sed -i \
    "s/# gateway_external_network_id =.*/gateway_external_network_id = $EXT_NET_ID/" \
    /etc/neutron/l3_agent.ini
  source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh neutron
fi

if [ `neutron subnet-list | grep -c 'ext-subnet'` -eq 0 ]; then
  neutron subnet-create ext-net --name ext-subnet \
    --allocation-pool start=${FLOATING_START},end=${FLOATING_END} \
    --disable-dhcp --gateway ${PUBLIC_GW} ${PUBLIC_RANGE}
fi

# flat-net uses a different scope on the same range as ext-net
if [ `neutron net-list | grep -c 'flat-net'` -eq 0 ]; then
  neutron net-create flat-net --shared --router:external=True \
    --provider:physical_network physnet1 --provider:network_type flat
fi

if [ `neutron subnet-list | grep -c 'flat-subnet'` -eq 0 ]; then
  neutron subnet-create flat-net --name flat-subnet \
    --allocation-pool start=${FLAT_START},end=${FLAT_END} \
    --gateway ${PUBLIC_GW} ${PUBLIC_RANGE}
fi

if [ `neutron router-list | grep -c "${DEMO_TENANT_NAME}-router"` -eq 0 ]; then
  neutron router-create --tenant-id ${DEMO_TENANT_ID} ${DEMO_TENANT_NAME}-router
  neutron router-gateway-set ${DEMO_TENANT_NAME}-router ext-net
fi

if [ `neutron net-list | grep -c ${DEMO_TENANT_NAME}-net` -eq 0 ]; then
  neutron net-create --tenant-id ${DEMO_TENANT_ID} ${DEMO_TENANT_NAME}-net

  neutron subnet-create ${DEMO_TENANT_NAME}-net --name ${DEMO_TENANT_NAME}-subnet --tenant-id ${DEMO_TENANT_ID} \
    --gateway ${DEMO_TENANT_FIXED_GW} ${DEMO_TENANT_FIXED_RANGE}

  neutron router-interface-add ${DEMO_TENANT_NAME}-router ${DEMO_TENANT_NAME}-subnet
fi

OS_TENANT_NAME=$DEMO_TENANT_NAME

for n in net subnet router; do neutron ${n}-list; done

