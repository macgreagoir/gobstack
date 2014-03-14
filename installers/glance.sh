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

sed -i "s|^sql_connection.*|sql_connection = mysql://glance:${MYSQL_GLANCE_PASS}@${CONTROLLER_PUBLIC_IP}/glance|" \
  /etc/glance/glance-{registry,api}.conf

service glance-registry restart
service glance-api restart

# glance db is version controlled in precise for upgrades
# set to version 0
glance-manage version_control 0
glance-manage db_sync


## now update the api and registry conf files
# service account set in keystone_install.sh
#

# use swift for storage
# segment files > 1GB in 100MB chunks
sed -i \
  -e 's/^default_store.*/default_store = swift/' \
  -e "s|^swift_store_auth_address.*|swift_store_auth_address = ${OS_AUTH_URL}|" \
  -e 's/^swift_store_user.*/swift_store_user = service:swift/' \
  -e 's/^swift_store_key.*/swift_store_key = swift/' \
  -e 's/^swift_store_container.*/swift_store_container = glance/' \
  -e 's/^swift_store_create_container_on_put.*/swift_store_create_container_on_put = True/' \
  -e 's/^swift_store_large_object_size.*/swift_store_large_object_size = 1024/' \
  -e 's/^swift_store_large_object_chunk_size.*/swift_store_large_object_chunk_size = 100/' \
  /etc/glance/glance-api.conf

# rm the filter:authtoken block and replace
sed -i '/\[filter\:authtoken\]/,/^$/d' /etc/glance/glance-{api,registry}-paste.ini

cat >> /etc/glance/glance-api-paste.ini <<GAPIP

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = glance

GAPIP

cat >> /etc/glance/glance-registry-paste.ini <<GRP

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = glance

GRP

# rm the keystone_authtoken and paste_deploy blocks and replace
sed -i '/\[keystone_authtoken\]/,/^$/d' /etc/glance/glance-{api,registry}.conf
sed -i '/\[paste_deploy\]/,/^$/d' /etc/glance/glance-{api,registry}.conf

cat >> /etc/glance/glance-api.conf <<GAPI

[keystone_authtoken]
auth_host = ${CONTROLLER_PUBLIC_IP}
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = glance

[paste_deploy]
# Name of the paste configuration file that defines the available pipelines
#config_file = glance-api-paste.ini
config_file = /etc/glance/glance-api-paste.ini
#
# Partial name of a pipeline in your paste configuration file with the
# service name removed. For example, if your paste section name is
# [pipeline:glance-api-keystone], you would configure the flavor below
# as 'keystone'.
#flavor=
flavor = keystone

GAPI

cat >> /etc/glance/glance-registry.conf <<GR

[keystone_authtoken]
auth_host = ${CONTROLLER_PUBLIC_IP}
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = glance
admin_password = glance

[paste_deploy]
# Name of the paste configuration file that defines the available pipelines
#config_file = glance-registry-paste.ini
config_file = /etc/glance/glance-registry-paste.ini
#
# Partial name of a pipeline in your paste configuration file with the
# service name removed. For example, if your paste section name is
# [pipeline:glance-api-keystone], you would configure the flavor below
# as 'keystone'.
#flavor=
flavor = keystone

GR

service glance-api restart
service glance-registry restart
