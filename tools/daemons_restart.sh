#!/bin/bash
## Restart any systemd services matching ${1}-*

if [ ! "$1" ]; then
  echo "usage: $0 nova|cinder|neutron" 1>&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

for s in $(systemctl list-units --type=service --state=loaded --no-legend --no-pager "${1}-*.service" \
  | awk '{print $1}'); do
  systemctl restart "$s"
done

# compute nodes will have this
if systemctl list-units --type=service --no-legend --no-pager 'libvirtd.service' | grep -q libvirtd; then
  systemctl restart libvirtd
fi

# seems to need time for things to start up, so postpone return
sleep 5
