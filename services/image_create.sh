#!/bin/bash
## upload and manage an image

source ${BASH_SOURCE%/*}/../defaults.sh

if [[ -z $(ip addr | grep "${CONTROLLER_PUBLIC_IP}") ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

# let's make this script rerunnable
if [[ -n $(openstack image list -f value -c Name | grep 'CirrOS') ]]; then
  echo "You've already done this:"
  openstack image list
  exit 1
fi

CIRROS_VERSION=0.6.2
mkdir -p /tmp/images
cd /tmp/images
if [ ! -f "/tmp/images/cirros-${CIRROS_VERSION}-x86_64-disk.img" ]; then
  wget "http://download.cirros-cloud.net/${CIRROS_VERSION}/cirros-${CIRROS_VERSION}-x86_64-disk.img"
fi

openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --file cirros-${CIRROS_VERSION}-x86_64-disk.img \
  "CirrOS ${CIRROS_VERSION} x86_64"

openstack image list

CIRROS_IMAGE_ID=$(openstack image list -f value -c ID -c Name | awk '/CirrOS/ {print $1}')
DEMO_PROJECT_ID=$(openstack project show ${DEMO_TENANT_NAME} -f value -c id)

openstack image add project ${CIRROS_IMAGE_ID} ${DEMO_PROJECT_ID} || true
openstack image member list ${CIRROS_IMAGE_ID} || true
