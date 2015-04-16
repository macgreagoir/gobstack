#!/bin/bash
## Install and configure the cinder block storage service

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# this expects to run on a storage node
if [[ -z `ip addr | grep "${STORAGE_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${STORAGE_PUBLIC_IP}" 1>&2
  exit 1
fi

## install cinder et al
apt-get -y install \
 mysql-client python-mysqldb xfsprogs \
 cinder-api cinder-scheduler cinder-volume python-cinderclient \
 open-iscsi tgt sysfsutils

mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE cinder;"
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '${MYSQL_CINDER_PASS}';"
mysql -h${CONTROLLER_PUBLIC_IP} -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '${MYSQL_CINDER_PASS}';"

## create /dev/sdc1
# do we have sdc1 already?
disks=$(fdisk /dev/sdc 2>/dev/null <<FDISK
p
q
FDISK
)

if [[ $disks =~ 'sdc1' ]]; then
  echo "/dev/sdc1 exists"
else
  # create it anew as a Linux LVM type...
  fdisk /dev/sdc <<FDISK
n
p
1


t
8e
p
w
FDISK
fi

## create the volume group
# 'cinder-volumes' as set in cinder.conf
(( pvdisplay /dev/sdc1 && vgdisplay cinder-volumes ) || \
  ( pvcreate /dev/sdc1 && vgcreate cinder-volumes /dev/sdc1 )) > /dev/null 2>&1

## update the confs
cat > /etc/cinder/cinder.conf <<CCONF
[DEFAULT]
my_ip = ${STORAGE_PUBLIC_IP}
rootwrap_config = /etc/cinder/rootwrap.conf
connection = mysql://cinder:${MYSQL_CINDER_PASS}@${CONTROLLER_PUBLIC_IP}/cinder
api_paste_config = /etc/cinder/api-paste.ini

iscsi_helper = tgtadm
iscsi_ip_address = ${STORAGE_PRIVATE_IP}
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
state_path = /var/lib/cinder
lock_path = /var/lock/cinder
volumes_dir = /var/lib/cinder/volumes

# Add these when not using the defaults.
rpc_backend = rabbit
rabbit_host = ${CONTROLLER_PUBLIC_IP}
rabbit_pasword = guest

[keystone_authtoken]
auth_uri = http://${CONTROLLER_PUBLIC_IP}:5000/v2.0
identity_uri = http://${CONTROLLER_PUBLIC_IP}:35357
admin_tenant_name = service
admin_user = cinder
admin_password = cinder

CCONF

## populate the db
su -s /bin/sh -c "cinder-manage db sync" cinder

## restart the cinder daemons
source ${BASH_SOURCE%/*}/../tools/daemons_restart.sh cinder

## get a stackrc
source ${BASH_SOURCE%/*}/../tools/stackrc_write.sh

