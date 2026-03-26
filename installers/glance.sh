#!/bin/bash
## Install and configure the glance image service

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [[ -z $(ip addr | grep "${CONTROLLER_PUBLIC_IP}") ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

## glance install
apt-get install -y glance python3-glanceclient

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE IF NOT EXISTS glance;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY '${MYSQL_GLANCE_PASS}';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${MYSQL_GLANCE_PASS}';"

## configure glance-api.conf
sed -i \
  -e "s|^#\s*connection\s*=.*|connection = mysql+pymysql://glance:${MYSQL_GLANCE_PASS}@${CONTROLLER_PUBLIC_IP}/glance|" \
  /etc/glance/glance-api.conf

# use filesystem for image storage
if [ -z "$(grep '^default_store\s*=\s*file' /etc/glance/glance-api.conf)" ]; then
  sed -i '/^\[glance_store\]/,/^\[/ {
    /^\[glance_store\]/ a\
default_store = file\nstores = glance.store.filesystem.Store\nfilesystem_store_datadir = /var/lib/glance/images/
  }' /etc/glance/glance-api.conf 2>/dev/null || true
fi

# rm the keystone_authtoken block and replace with v3
sed -i '/\[keystone_authtoken\]/,/^$/d' /etc/glance/glance-api.conf

cat >> /etc/glance/glance-api.conf <<KAUTH

[keystone_authtoken]
www_authenticate_uri = http://${CONTROLLER_PUBLIC_IP}:5000
auth_url = http://${CONTROLLER_PUBLIC_IP}:5000
memcached_servers = ${CONTROLLER_PUBLIC_IP}:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = glance

[paste_deploy]
flavor = keystone

KAUTH

# clean up and sync db
rm -f /var/lib/glance/glance.sqlite
su -s /bin/sh -c "glance-manage db_sync" glance

# restart services
service glance-api restart
