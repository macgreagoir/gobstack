#!/bin/bash
## Install and configure a nova compute node

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# use nova-compute-qemu to avoid kvm inside a VM
apt-get install -y \
  ntp \
  nova-compute \
  nova-network \
  nova-api-metadata \
  nova-compute-qemu

# let it route
sysctl -w net.ipv4.ip_forward=1

# write out nova.conf
source ${BASH_SOURCE%/*}/../files/nova_conf.sh

# write out nova api-paste.ini for keystone
source ${BASH_SOURCE%/*}/../files/nova_api_paste_ini.sh

# restart 'em all
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh nova

