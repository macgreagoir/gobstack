#!/bin/bash
## bootstrap the whole system

echo "You have seven (7) seconds to stop me before I destroy and rebuild your VMs."
echo "Ctrl+C now to kill me..."
sleep 3 # time to read the message

count=8
while (( count-- > 0 )); do
  echo "$count ..."
  sleep 1
done

vagrant halt
vagrant destroy -f
vagrant up
controller_install='for s in keystone_install glance_install glance_image_test nova_controller_install; do sudo /vagrant/${s}.sh; done'
vagrant ssh controller0 -c "$controller_install"
vagrant ssh storage0 -c "sudo /vagrant/swift_install.sh"
for i in 0 1; do vagrant ssh compute$i -c "sudo /vagrant/nova_compute_install.sh"; done
