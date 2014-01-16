#!/bin/bash
## Install and configure the swift object storage service

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

## install swift et al, and python-keystone
apt-get -y install \
  curl memcached ntp parted python-webob xfsprogs \
  swift swift-account swift-container swift-object swift-proxy \
  python-keystone


## create /dev/sdb1
# do we have sdb1 already?
disks=$(fdisk /dev/sdb 2>/dev/null <<FDISK
p
q
FDISK
)

if [[ $disks =~ 'sdb1' ]]; then
  # we expect these to be in place
  echo "/dev/sdb1 exists"
  file /dev/sdb1
  mount | grep sdb1
  ls -l /srv/sdb1
  ls -l /etc/rsynsd.conf
else
  # create it anew
  fdisk /dev/sdb <<FDISK
n
p
1


p
w
FDISK

  # ...and mount it
  partprobe
  mkfs.xfs -i size=1024 /dev/sdb1
  mkdir -p /mnt/sdb1
  sed -i "/\/dev\/sdb1/d" /etc/fstab
  echo "/dev/sdb1 /mnt/sdb1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab
  mount /dev/sdb1
fi

# tree for this storage configuration
# we are creating four virtual devices on one host
mkdir -p /mnt/sdb1/{1..4}
ln -s /mnt/sdb1/{1..4} /srv
for i in {1..4}; do mkdir -p /srv/$i/node/sdb$i; done
# ...and system conf
mkdir -p /etc/swift/{account-server,container-server,object-server}
mkdir -p /var/cache/swift
mkdir -p /var/run/swift
chown -R swift:swift /mnt/sdb1/{1..4} /srv/{1..4} /etc/swift /var/cache/swift /var/run/swift


## modules for multiple rsync targets: `rsync localhost::foo60xx`
# based on the tree above
# max connections should be higher in production: man rsyncd.conf
cat > /etc/rsyncd.conf<<RSD
# common

uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 127.0.0.1

###

RSD

for i in {1..4}; do
  cat >> /etc/rsyncd.conf <<RSD
# Instance $i

[account60${i}2]
max connections = 25
path = /srv/${i}/node/
read only = false
lock file = /var/lock/account60${i}2.lock

[container60${i}1]
max connections = 25
path = /srv/${i}/node/
read only = false
lock file = /var/lock/container60${i}1.lock

[object60${i}0]
max connections = 25
path = /srv/${i}/node/
read only = false
lock file = /var/lock/object60${i}0.lock

###

RSD
done

sed -i "s/RSYNC_ENABLE=false/RSYNC_ENABLE=true/" /etc/default/rsync
service rsync restart
rsync rsync://pub@localhost


## generate a hash to use across all swift nodes in the system
if [ ! `grep swift_hash_path_suffix /etc/swift/swift.conf 2>/dev/null` ]; then
  SWIFT_PRE=`< /dev/urandom tr -dc A-Za-z0-9_ | head -c16`
  SWIFT_SUF=`< /dev/urandom tr -dc A-Za-z0-9_ | head -c16`
  cat > /etc/swift/swift.conf <<SCONF
[swift-hash]
swift_hash_path_prefix = ${SWIFT_PRE}
swift_hash_path_suffix = ${SWIFT_SUF}
SCONF
fi

## now we need /etc/swift{account,container,object}-server/{1..4}.conf
# rm the standard single conf file per service
rm -f /etc/swift/{account,container,object}-server.conf

for i in {1..4}; do
  cat > /etc/swift/account-server/${i}.conf <<AST
[DEFAULT]
devices = /srv/${i}/node
mount_check = false
bind_port = 60${i}2

[pipeline:main]
pipeline = account-server

[app:account-server]
use = egg:swift#account
set log_facility = LOG_LOCAL$((i+1))
set log_name = account-server${i}

[account-replicator]
log_name = account-replicator${i}
vm_test_mode = yes

[account-auditor]
log_name = account-replicator${i}

[account-reaper]
log_name = account-auditor${i}

AST

  cat > /etc/swift/container-server/${i}.conf <<CST
[DEFAULT]
devices = /srv/${i}/node
mount_check = false
bind_port = 60${i}1

[pipeline:main]
pipeline = container-server

[app:container-server]
use = egg:swift#container
set log_facility = LOG_LOCAL$((i+1))
set log_name = container-server${i}

[container-replicator]
log_facility = LOG_LOCAL$((i+1))
log_name = container-replicator${i}
vm_test_mode = yes

[container-updater]
log_facility = LOG_LOCAL$((i+1))
log_name = container-updater${i}

[container-auditor]
log_facility = LOG_LOCAL$((i+1))
log_name = container-auditor${i}

[container-sync]
log_facility = LOG_LOCAL$((i+1))
log_name = container-sync${i}

CST

  cat > /etc/swift/object-server/${i}.conf <<OST
[DEFAULT]
devices = /srv/${i}/node
mount_check = false
bind_port = 60${i}0

[pipeline:main]
pipeline = object-server

[app:object-server]
use = egg:swift#object
set log_facility = LOG_LOCAL$((i+1))
set log_name = object-server${i}

[object-replicator]
log_facility = LOG_LOCAL$((i+1))
log_name = object-replicator${i}
vm_test_mode = yes

[object-updater]
log_facility = LOG_LOCAL$((i+1))
log_name = object-updater${i}

[object-auditor]
log_facility = LOG_LOCAL$((i+1))
log_name = object-auditor${i}

OST
done


## now create Account, Container, Object rings with the four virtual devices
cd /etc/swift
rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

port_unit=0
# order dictates port_unit
for s in object container account; do
  swift-ring-builder ${s}.builder create 18 3 1
  for i in {1..4}; do
    swift-ring-builder ${s}.builder add r1z${i}-127.0.0.1:60${i}${port_unit}/sdb$i 1
  done
  swift-ring-builder ${s}.builder rebalance
  (( port_unit++ ))
done
cd


# proxy conf
# keystone for swift configured in keystone_install.sh
cat > /etc/swift/proxy-server.conf <<SPRY
[DEFAULT]
bind_port = 8080
eventlet_debug = true

[pipeline:main]
pipeline = catch_errors healthcheck cache authtoken keystoneauth proxy-logging proxy-server

[filter:catch_errors]
use = egg:swift#catch_errors

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = Member,admin

[filter:proxy-logging]
use = egg:swift#proxy_logging

[filter:cache]
use = egg:swift#memcache

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true
set log_facility = LOG_LOCAL1

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = ${CONTROLLER_PUBLIC_IP}
auth_port = 35357
auth_protocol = http
auth_uri = http://${CONTROLLER_PUBLIC_IP}:5000
admin_tenant_name = service
admin_user = swift
admin_password = swift
cache = swift.cache
include_service_catalog = False
signing_dir = /var/cache/swift/keystone-signing

SPRY

cat > /etc/swift/object-expirer.conf <<OEX
[DEFAULT]
log_facility = LOG_LOCAL6

[object-expirer]
interval = 300

[pipeline:main]
pipeline = catch_errors cache proxy-server

[app:proxy-server]
use = egg:swift#proxy

[filter:cache]
use = egg:swift#memcache

[filter:catch_errors]
use = egg:swift#catch_errors

OEX

## start 'er up
swift-init all restart
swift-init all stop
# should we really need to do this?
chown -R swift:swift /mnt/sdb1/{1..4} /srv/{1..4} /etc/swift /var/cache/swift /var/run/swift
swift-init all start

swift -A $OS_AUTH_URL -U service:swift -K swift -V 2.0 stat

