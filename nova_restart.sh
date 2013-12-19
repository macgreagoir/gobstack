#!/bin/bash
## Restart the various nova services

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

for s in `ls /etc/init/nova-* | cut -d '/' -f4 | cut -d '.' -f1`
do service $s restart; done

# compute nodes will have this
if [ -f /etc/init/libvirt-bin.conf ]; then
  service libvirt-bin restart
fi

# seems to need time for things to start up, so postpone return
sleep 3
