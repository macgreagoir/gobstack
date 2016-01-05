## model an OpenStack system using Ubuntu trusty64 box

# use juno
repo_update = "echo 'deb http://ubuntu-cloud.archive.canonical.com/ubuntu "
repo_update << "trusty-proposed/juno main' > /etc/apt/sources.list.d/juno.list; "
repo_update << "sed -i 's|/us\.|/|' /etc/apt/sources.list; "
repo_update << "apt-get update; apt-get install -y ubuntu-cloud-keyring; "
repo_update << "apt-get update"

# try to cache packages on controller0
# TODO hard-coded addr could be based on nodes hash below
apt_proxy_server = "apt-get install -y apt-cacher-ng"
apt_proxy_client = "echo 'Acquire::http::Proxy \"http://172.16.0.100:3142\";' > /etc/apt/apt.conf.d/01proxy"

common_pkgs = "apt-get install -y curl ntp python-mysqldb vim"
# for more stable neutron in Ubuntu precise, but Vagrant doesn't like it
# common_pkgs << " linux-image-generic-lts-saucy linux-headers-generic-lts-saucy"
# common_pkgs << " virtualbox-guest-utils"

# no vagrant vm.network option for this
neutron_jumbo_frames = "ip link set dev eth2 mtu 9000\n"
neutron_jumbo_frames << "grep 'mtu 9000' /etc/rc.local || sed -i '/^exit 0/ i\\"
neutron_jumbo_frames << "ip link set dev eth2 mtu 9000' /etc/rc.local"

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
  config.vm.box = "trusty64"
  config.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"

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
            # apt-cacher-ng
            node.vm.network "forwarded_port", guest: 3142, host: 3142
            # vnc-console
            node.vm.network "forwarded_port", guest: 6080, host: 6080
        end
        node.vm.provider :virtualbox do |vbox|
          vbox.customize ["modifyvm", :id, "--cpus", 1]
          # promisc all over the shop for neutron flat-net
          vbox.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
          vbox.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
          case node_type
            when "controller"
              vbox.customize ["modifyvm", :id, "--memory", 2048]
            when "network"
              vbox.customize ["modifyvm", :id, "--memory", 512]
            when "storage"
              vbox.customize ["modifyvm", :id, "--memory", 2048]
              # sdb for swift
              unless File.exists?(".vagrant/#{hostname}_disk2.vdi")
                vbox.customize ["createhd", "--filename", ".vagrant/#{hostname}_disk2.vdi", 
                  "--size", 43*1024]
              end
              vbox.customize ["storageattach", :id, "--storagectl", 
                "SATAController", "--port", 1, "--device", 0, "--type", "hdd", 
                "--medium", ".vagrant/#{hostname}_disk2.vdi"]
              # sdc for cinder
              unless File.exists?(".vagrant/#{hostname}_disk3.vdi")
                vbox.customize ["createhd", "--filename", ".vagrant/#{hostname}_disk3.vdi", 
                  "--size", 10*1024]
              end
              vbox.customize ["storageattach", :id, "--storagectl", 
                "SATAController", "--port", 2, "--device", 0, "--type", "hdd", 
                "--medium", ".vagrant/#{hostname}_disk3.vdi"]
            when "compute"
              vbox.customize ["modifyvm", :id, "--memory", 2048]
          end
        end
        node.vm.provision :shell, :inline => hosts_file
        if node_type != "controller"
          node.vm.provision :shell, :inline => apt_proxy_client
        end
        node.vm.provision :shell, :inline => repo_update
        node.vm.provision :shell, :inline => common_pkgs
        if node_type == "controller"
          node.vm.provision :shell, :inline => apt_proxy_server
        end
        node.vm.provision :shell, :inline => neutron_jumbo_frames
      end
    end
  end
end
