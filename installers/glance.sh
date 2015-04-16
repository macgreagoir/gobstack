#!/bin/bash
## Install and configure the glance image service

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

## glance install
apt-get install -y glance python-glanceclient

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE glance;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY '${MYSQL_GLANCE_PASS}';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${MYSQL_GLANCE_PASS}';"

sed -i \
  -e "s|^#\s*connection\s*=.*|connection = mysql://glance:${MYSQL_GLANCE_PASS}@${CONTROLLER_PUBLIC_IP}/glance|" \
  -e 's/^\(sqlite_db.*\)/# \1/' \
  /etc/glance/glance-{registry,api}.conf

## now update the api and registry conf files
# service account set in keystone_install.sh
#
# use swift for storage
# segment files > 1GB in 100MB chunks
sed -i \
  -e "s|^swift_store_auth_address.*|swift_store_auth_address = ${OS_AUTH_URL}|" \
  -e 's/^swift_store_user.*/swift_store_user = service:swift/' \
  -e 's/^swift_store_key.*/swift_store_key = swift/' \
  -e 's/^swift_store_container.*/swift_store_container = glance/' \
  -e 's/^swift_store_create_container_on_put.*/swift_store_create_container_on_put = True/' \
  -e 's/^swift_store_large_object_size.*/swift_store_large_object_size = 1024/' \
  -e 's/^swift_store_large_object_chunk_size.*/swift_store_large_object_chunk_size = 100/' \
  /etc/glance/glance-api.conf

if [ -z "`grep ^stores /etc/glance/glance-api.conf`" ]; then
  sed -i \
    -e '/^default_store\s*=.*/d' \
    -e '/\[glance_store\]/ a\
default_store = swift\nstores = glance.store.swift.Store' \
  /etc/glance/glance-api.conf
fi

if [ -z "`grep ^rpc_backend /etc/glance/glance-api.conf`" ]; then
  sed -i '/^rabbit_host.*/ i\
rpc_backend = rabbit' /etc/glance/glance-api.conf
fi

for f in api registry; do
  if [ -z "`grep ^flavor /etc/glance/glance-${f}.conf`" ]; then
    sed -i '/^#flavor.*/ a\
flavor = keystone' /etc/glance/glance-${f}.conf
  fi
done

# rm the keystone_authtoken and replace
sed -i '/\[keystone_authtoken\]/,/^$/d' /etc/glance/glance-{api,registry}.conf

for f in api registry; do
  cat >> /etc/glance/glance-${f}.conf <<KAUTH

[keystone_authtoken]
auth_uri = http://${CONTROLLER_PUBLIC_IP}:5000/v2.0
identity_uri = http://${CONTROLLER_PUBLIC_IP}:35357
admin_tenant_name = service
admin_user = glance
admin_password = glance

KAUTH
done

# clean up and setup dbs
rm -f /var/lib/glance/glance.sqlite
su -s /bin/sh -c "glance-manage db_sync" glance

# restart 'em all
service glance-api restart
service glance-registry restart
