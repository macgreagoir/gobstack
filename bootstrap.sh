#!/bin/bash
## bootstrap the whole system

# check for an existing clean.sh before doing anything else
if [[ -f $(dirname "$0")/clean.sh ]]; then
  echo "clean.sh already exists; leaving it intact."
else
  # record which requirements this run installs so clean.sh can purge them
  INSTALLED_VAGRANT=false
  INSTALLED_VAGRANT_REPO=false
  INSTALLED_VBOX=false

  if [[ -f /etc/debian_version ]]; then
    if [[ -z $(which vagrant) ]]; then
      DISTRO_CODENAME=$(lsb_release -cs)
      # fall back to noble if this codename isn't in HashiCorp's repo
      HASHICORP_CODENAME=${DISTRO_CODENAME}
      curl -fsSL "https://apt.releases.hashicorp.com/dists/${DISTRO_CODENAME}/Release" \
        -o /dev/null --silent --fail || HASHICORP_CODENAME=noble
      curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
      echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp.gpg] \
https://apt.releases.hashicorp.com ${HASHICORP_CODENAME} main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update
      sudo apt-get install -y vagrant
      INSTALLED_VAGRANT=true
      INSTALLED_VAGRANT_REPO=true
    fi
    if [[ -z $(which vboxmanage) ]]; then
      sudo apt-get install -y virtualbox
      INSTALLED_VBOX=true
    fi
  fi

  # write clean.sh
  cat > $(dirname "$0")/clean.sh <<CLEAN
#!/bin/bash
## clean up everything installed by bootstrap.sh

vagrant halt
vagrant destroy -f

CLEAN

  if [[ $INSTALLED_VAGRANT == true ]]; then
    echo "sudo apt-get purge -y vagrant" >> $(dirname "$0")/clean.sh
  fi
  if [[ $INSTALLED_VAGRANT_REPO == true ]]; then
    echo "sudo rm -f /usr/share/keyrings/hashicorp.gpg /etc/apt/sources.list.d/hashicorp.list" \
      >> $(dirname "$0")/clean.sh
  fi
  if [[ $INSTALLED_VBOX == true ]]; then
    echo "sudo apt-get purge -y virtualbox" >> $(dirname "$0")/clean.sh
  fi

  chmod +x $(dirname "$0")/clean.sh
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
