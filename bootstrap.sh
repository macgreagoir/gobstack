#!/bin/bash
## bootstrap the whole system

# install requirements on Ubuntu/Debian if not already present
if [[ -f /etc/debian_version ]]; then
  [[ -n $(which vagrant) ]]    || sudo apt-get install -y vagrant
  [[ -n $(which vboxmanage) ]] || sudo apt-get install -y virtualbox
fi

echo "You have seven (7) seconds to stop me before I destroy and rebuild your VMs."
echo "Ctrl+C now to kill me..."
sleep 3 # time to read the message

count=7
while (( count-- > 0 )); do
  echo $(( count + 1 ))
  sleep 1
done

vagrant halt
vagrant destroy -f
vagrant up
controller_install='for s in mariadb keystone glance placement neutron_controller nova_controller; do sudo /vagrant/installers/${s}.sh; done'
vagrant ssh controller0 -c "$controller_install"
vagrant ssh network0 -c 'sudo /vagrant/installers/neutron_network.sh'
vagrant ssh storage0 -c 'for s in swift cinder; do sudo /vagrant/installers/${s}.sh; done'
vagrant ssh controller0 -c 'sudo /vagrant/services/networks_create.sh; sudo /vagrant/services/image_create.sh'
for i in 0 1; do vagrant ssh compute$i -c 'sudo /vagrant/installers/nova_compute.sh'; done
