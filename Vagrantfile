## model an OpenStack system using Ubuntu noble64 box

# use dalmatian (OpenStack 2024.2) from the Ubuntu Cloud Archive
repo_update = "apt-get install -y software-properties-common; "
repo_update << "apt-get install -y ubuntu-cloud-keyring; "
repo_update << "echo 'deb http://ubuntu-cloud.archive.canonical.com/ubuntu "
repo_update << "noble-updates/dalmatian main' > /etc/apt/sources.list.d/dalmatian.list; "
repo_update << "apt-get update"

common_pkgs = "apt-get install -y curl chrony python3-pymysql vim"

# no vagrant vm.network option for this; MTU is not persisted across reboots
neutron_jumbo_frames = "ip link set dev eth2 mtu 9000"

# 'node_type' => [num_nodes, starting_ip_addr]
nodes = {
  'controller' => [1, 100],
  'network'    => [1, 120],
  'storage'    => [1, 150],
  'compute'    => [2, 200],
}

# used to build hosts file
# TODO IP addr coding again. Maybe prefixes in a hash for single entry
hosts_file = "sed -i '/^127\.0\.1\.1/d' /etc/hosts\n"
hosts_file << "sed -i '/^# gobstack nodes/,/^# end of gobstack nodes/d' /etc/hosts\n"
hosts_file << "cat >> /etc/hosts <<HOSTS\n"
hosts_file << "# gobstack nodes\n"
  nodes.each do |node_type, (count, ip_addr)|
    count.times do |i|
      hosts_file << "172.16.0.#{ip_addr+i} #{node_type}#{i}\n"
    end
  end
hosts_file << "# end of gobstack nodes\n"
hosts_file << "HOSTS\n"

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  nodes.each do |node_type, (count, ip_addr)|
    count.times do |i|
      hostname = "%s%d" % [node_type, i]

      config.vm.define "#{hostname}" do |node|
        node.vm.hostname = "#{hostname}.local"
        node.vm.network :private_network, :ip => "172.16.0.#{ip_addr+i}",
          :netmask => "255.255.255.0"
        node.vm.network :private_network, :ip => "10.0.0.#{ip_addr+i}",
          :netmask => "255.255.255.0"
        case node_type
          when "controller"
            # vnc-console
            node.vm.network "forwarded_port", guest: 6080, host: 6080
          when "network"
            # this will be reconfigured but needs here for Vagrant to provision
            node.vm.network :private_network, :ip => "172.16.1.#{ip_addr+i}",
              :netmask => "255.255.255.0"
        end
        node.vm.provider :virtualbox do |vbox|
          vbox.customize ["modifyvm", :id, "--cpus", 1]
          case node_type
            when "controller"
              vbox.customize ["modifyvm", :id, "--memory", 2048]
            when "network"
              vbox.customize ["modifyvm", :id, "--memory", 512]
            when "storage"
              vbox.customize ["modifyvm", :id, "--memory", 2048]
              # sdb for swift
              unless File.exist?(".vagrant/#{hostname}_disk2.vdi")
                vbox.customize ["createhd", "--filename", ".vagrant/#{hostname}_disk2.vdi",
                  "--size", 43*1024]
              end
              vbox.customize ["storageattach", :id, "--storagectl",
                "SATA Controller", "--port", 1, "--device", 0, "--type", "hdd",
                "--medium", ".vagrant/#{hostname}_disk2.vdi"]
              # sdc for cinder
              unless File.exist?(".vagrant/#{hostname}_disk3.vdi")
                vbox.customize ["createhd", "--filename", ".vagrant/#{hostname}_disk3.vdi",
                  "--size", 10*1024]
              end
              vbox.customize ["storageattach", :id, "--storagectl",
                "SATA Controller", "--port", 2, "--device", 0, "--type", "hdd",
                "--medium", ".vagrant/#{hostname}_disk3.vdi"]
            when "compute"
              vbox.customize ["modifyvm", :id, "--memory", 2048]
              vbox.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
          end
        end
        node.vm.provision :shell, :inline => hosts_file
        node.vm.provision :shell, :inline => repo_update
        node.vm.provision :shell, :inline => common_pkgs
        node.vm.provision :shell, :inline => neutron_jumbo_frames
      end
    end
  end
end
