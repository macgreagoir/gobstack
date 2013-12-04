#!/bin/bash
## Install and configure a nova compute node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

apt-get update
# use nova-compute-qemu to avoid kvm inside a VM
apt-get install -y \
  ntp \
  nova-compute \
  nova-network \
  nova-api-metadata \
  nova-compute-qemu

# write out nova.conf
source ${BASH_SOURCE%/*}/nova_conf.sh

# write out nova api-paste.ini for keystone
source ${BASH_SOURCE%/*}/nova_api_paste_ini.sh
service libvirt-bin restart
