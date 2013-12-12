## model an OpenStack system using Ubuntu precise64 box

# use grizzly and uk mirrors
repo_update = "echo 'deb http://ubuntu-cloud.archive.canonical.com/ubuntu "
repo_update << "precise-proposed/grizzly main' > /etc/apt/sources.list.d/grizzly.list; "
repo_update << "sed -i 's|/us\.|/uk\.|' /etc/apt/sources.list; "
repo_update << "apt-get update; apt-get install -y ubuntu-cloud-keyring; "
repo_update << "apt-get update"

# 'node_type' => [num_nodes, starting_ip_addr]
nodes = {
  'controller' => [1, 100],
  'storage' => [1, 150],
  'compute'    => [2, 200],
}

Vagrant.configure("2") do |config|
  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  nodes.each do |node_type, (count, ip_addr)|
    count.times do |i|
      hostname = "%s%d" % [node_type, i]

      config.vm.define "#{hostname}" do |node|
        node.vm.hostname = "#{hostname}.local"
        node.vm.network :private_network, :ip => "172.20.0.#{ip_addr+i}", 
          :netmask => "255.255.0.0"
        node.vm.network :private_network, :ip => "10.20.0.#{ip_addr+i}", 
          :netmask => "255.255.0.0"
        node.vm.provider :virtualbox do |vbox|
          # these mem settings are way too low, so x2 if ye can
          if node_type == "compute"
            vbox.customize ["modifyvm", :id, "--memory", 1024]
            vbox.customize ["modifyvm", :id, "--cpus", 2]
          else
            vbox.customize ["modifyvm", :id, "--memory", 512]
            vbox.customize ["modifyvm", :id, "--cpus", 1]
          end
          if node_type == "storage"
            vbox.customize ["createhd", "--filename", ".vagrant/#{hostname}_disk2.vdi", 
              "--size", 2048*1024]
            vbox.customize ["storageattach", :id, "--storagectl", 
              "SATA Controller", "--port", 1, "--device", 0, "--type", "hdd", 
              "--medium", ".vagrant/#{hostname}_disk2.vdi"]
          end
        end
        node.vm.provision :shell, :inline => repo_update
      end
    end
  end
end
