openstack_demo
==============

Scripted openstack installation using Vagrant


0. `you@host:~$ vagrant up`
0. `you@host:~$ vagrant ssh controller0`
0. On controller0:

    ```
    vagrant@controller0:~$ sudo /vagrant/keystone_install.sh
    vagrant@controller0:~$ sudo /vagrant/glance_install.sh
    vagrant@controller0:~$ sudo /vagrant/glance_image_test.sh
    vagrant@controller0:~$ sudo /vagrant/nova_controller_install.sh
    ```

0. Install swift on the storage node:
    `you@host:~$ vagrant ssh storage0 -c "sudo /vagrant/swift_install.sh"`

0. Install nova on the compute nodes:
    `you@host:~$ for i in 0 1; do vagrant ssh compute$i -c "sudo /vagrant/nova_compute_install.sh"; done`

