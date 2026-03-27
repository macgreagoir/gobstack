#!/bin/bash
## bootstrap the whole system

VBOX_NETWORKS=/etc/vbox/networks.conf
VBOX_RANGES="* 172.16.0.0/24 172.16.1.0/24 10.0.0.0/24 10.0.1.0/24"

ensure_vbox_networks() {
  if [[ -z $(grep -s '172\.16\.0\.0' ${VBOX_NETWORKS}) ]]; then
    if [[ ! -d /etc/vbox ]]; then
      sudo mkdir /etc/vbox
      CREATED_VBOX_DIR=true
    fi
    echo "${VBOX_RANGES}" | sudo tee -a ${VBOX_NETWORKS}
    return 0
  fi
  return 1
}

# check for an existing clean.sh before doing anything else
if [[ -f $(dirname "$0")/clean.sh ]]; then
  echo "clean.sh already exists; leaving it intact."
else
  # record which requirements this run installs so clean.sh can purge them
  INSTALLED_VAGRANT=false
  INSTALLED_VAGRANT_REPO=false
  INSTALLED_VBOX=false
  ADDED_VBOX_NETWORKS=false

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

  CREATED_VBOX_DIR=false
  ensure_vbox_networks && ADDED_VBOX_NETWORKS=true

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
  if [[ $ADDED_VBOX_NETWORKS == true ]]; then
    echo "sudo sed -i '/172\.16\.0\.0/d' ${VBOX_NETWORKS}" >> $(dirname "$0")/clean.sh
    if [[ $CREATED_VBOX_DIR == true ]]; then
      echo "sudo rmdir /etc/vbox" >> $(dirname "$0")/clean.sh
    fi
  fi

  chmod +x $(dirname "$0")/clean.sh
fi

# allow our host-only network ranges in VirtualBox (runs on every bootstrap)
CREATED_VBOX_DIR=false
if ensure_vbox_networks; then
  echo "sudo sed -i '/172\.16\.0\.0/d' ${VBOX_NETWORKS}" >> $(dirname "$0")/clean.sh
  if [[ $CREATED_VBOX_DIR == true ]]; then
    echo "sudo rmdir /etc/vbox" >> $(dirname "$0")/clean.sh
  fi
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
vagrant ssh controller0 -c 'sudo /vagrant/services/networks_create.sh; sudo /vagrant/services/image_create.sh; sudo /vagrant/services/flavours_create.sh'
for i in 0 1; do vagrant ssh compute$i -c 'sudo /vagrant/installers/nova_compute.sh'; done
vagrant ssh controller0 -c 'sudo nova-manage cell_v2 discover_hosts --verbose'
