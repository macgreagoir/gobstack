#!/bin/bash -e
## Install and configure the placement API service

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [[ -z $(ip addr | grep "${CONTROLLER_PUBLIC_IP}") ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

apt-get install -y placement-api

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE IF NOT EXISTS placement;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON placement.* TO 'placement'@'%' IDENTIFIED BY '${MYSQL_PLACEMENT_PASS}';"

cat > /etc/placement/placement.conf <<PCONF
[DEFAULT]
log_dir = /var/log/placement

[api]
auth_strategy = keystone

[keystone_authtoken]
www_authenticate_uri = http://${CONTROLLER_PUBLIC_IP}:5000
auth_url = http://${CONTROLLER_PUBLIC_IP}:5000
memcached_servers = ${CONTROLLER_PUBLIC_IP}:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = placement

[placement_database]
connection = mysql+pymysql://placement:${MYSQL_PLACEMENT_PASS}@${CONTROLLER_PUBLIC_IP}/placement

PCONF

su -s /bin/sh -c "placement-manage db sync" placement

service apache2 restart

# verify
placement-status upgrade check
