#!/bin/bash
## Create standard flavours

source ${BASH_SOURCE%/*}/../defaults.sh

# this to check we are on the controller
if [[ -z $(ip addr | grep "${CONTROLLER_PUBLIC_IP}") ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

# id, name, ram (MB), disk (GB), vcpus
flavours=(
  "1 m1.tiny   512  1 1"
  "2 m1.small  2048 20 1"
  "3 m1.medium 4096 40 2"
  "4 m1.large  8192 80 4"
)

for f in "${flavours[@]}"; do
  read -r id name ram disk vcpus <<< "$f"
  if openstack flavor show ${name} >/dev/null 2>&1; then
    echo "Flavour ${name} already exists"
  else
    openstack flavor create --id ${id} --ram ${ram} --disk ${disk} --vcpus ${vcpus} ${name}
  fi
done

openstack flavor list
