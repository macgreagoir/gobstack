#!/bin/bash
## upload and manage an image

source ${BASH_SOURCE%/*}/defaults.sh

if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

# let's make this script rerunable
if [[ -n `glance image-list | awk '/\ CirrOS/ {print $2}'` ]]; then
  echo "You've already done this:"
  glance image-list
  exit 1
fi


mkdir -p /tmp/images
cd /tmp/images
if [ ! -f "/tmp/images/cirros-0.3.1-x86_64-disk.img" ]; then 
  wget http://download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-disk.img
fi

glance image-create \
  --name='CirrOS 0.3.1 x86_64' \
  --disk-format=qcow2 \
  --container-format=bare \
  --public < cirros-0.3.1-x86_64-disk.img

glance image-list

CIRROS_IMAGE_ID=`glance image-list | awk '/\ CirrOS/ {print $2}'`
DEMO_TENANT_ID=`keystone tenant-list | awk "/\ ${DEMON_TENANT_NAME}\ / {print \\$2}"`
glance member-create --can-share $CIRROS_IMAGE_ID $DEMO_TENANT_ID

glance member-list --tenant-id $DEMO_TENANT_ID
glance member-list --image-id $CIRROS_IMAGE_ID

