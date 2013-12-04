openstack_demo
==============

Scripted openstack installation using Vagrant


0. `vagrant up`
0. `vagrant ssh controller0`, then
0. on controller0, run

    keystone_install.sh

    glance_install.sh

    glance_image_test.sh

    nova_controller_install.sh
0. `vagrant ssh compute[01]`
0. on compute[01], run

    nova_compute_install.sh

