#!/bin/bash -e
## Install and configure the keystone identity service

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

# this to check we are on the controller
if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

apt-get install -y keystone apache2 libapache2-mod-wsgi-py3 memcached python3-memcache

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "CREATE DATABASE IF NOT EXISTS keystone;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${MYSQL_KEYSTONE_PASS}';"

sed -i \
  -e "s|^connection.*=.*|connection = mysql+pymysql://keystone:${MYSQL_KEYSTONE_PASS}@${CONTROLLER_PUBLIC_IP}/keystone|" \
  /etc/keystone/keystone.conf

# enable fernet tokens (default in modern OpenStack)
if [ -z "`grep '^provider' /etc/keystone/keystone.conf`" ]; then
  sed -i '/^\[token\]/ a\
provider = fernet' /etc/keystone/keystone.conf
fi

# set log dir
sed -i "s|^#\s*log_dir.*|log_dir = /var/log/keystone|" \
  /etc/keystone/keystone.conf

# populate the db
su -s /bin/sh -c "keystone-manage db_sync" keystone

# initialise fernet key repositories
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

# bootstrap keystone - creates admin user, admin project, admin role, and endpoints
keystone-manage bootstrap \
  --bootstrap-password ${OS_PASSWORD} \
  --bootstrap-admin-url http://${CONTROLLER_PUBLIC_IP}:5000/v3/ \
  --bootstrap-internal-url http://${CONTROLLER_PUBLIC_IP}:5000/v3/ \
  --bootstrap-public-url http://${CONTROLLER_PUBLIC_IP}:5000/v3/ \
  --bootstrap-region-id RegionOne

# configure Apache to serve Keystone
sed -i "s/^ServerName.*/ServerName controller0/" /etc/apache2/apache2.conf 2>/dev/null || \
  echo "ServerName controller0" >> /etc/apache2/apache2.conf

service apache2 restart

# remove the default SQLite db
rm -f /var/lib/keystone/keystone.db

# cron the clean up of expired tokens
(crontab -l 2>&1 | grep -q token_flush) || \
  echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' \
  >> /var/spool/cron/crontabs/root

# let apache start
sleep 3

## now for some projects, roles and users
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "${DEMO_TENANT_DESC}" ${DEMO_TENANT_NAME}

# for Horizon and general use
openstack role create member

# from defaults.sh, the OS_* vars refer to the admin user
# admin user was already created by keystone-manage bootstrap in the admin project
# add admin to the demo project too
openstack role add --project ${DEMO_TENANT_NAME} --user admin admin

openstack user create --domain default --password ${DEMO_PASSWORD} ${DEMO_USERNAME}
openstack role add --project ${DEMO_TENANT_NAME} --user ${DEMO_USERNAME} member

openstack project list
openstack role list
openstack user list


## service users (one per service)
for svc in cinder glance neutron nova placement swift; do
  openstack user create --domain default --password ${svc} ${svc}
  openstack role add --project service --user ${svc} admin
done


## service catalogue entries and endpoints
# keystone endpoint was created by keystone-manage bootstrap above

openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack endpoint create --region RegionOne volume public "http://${STORAGE_PUBLIC_IP}:8776/v3/%(project_id)s"
openstack endpoint create --region RegionOne volume internal "http://${STORAGE_PUBLIC_IP}:8776/v3/%(project_id)s"
openstack endpoint create --region RegionOne volume admin "http://${STORAGE_PUBLIC_IP}:8776/v3/%(project_id)s"

openstack service create --name cinderv3 --description "OpenStack Block Storage v3" volumev3
openstack endpoint create --region RegionOne volumev3 public "http://${STORAGE_PUBLIC_IP}:8776/v3/%(project_id)s"
openstack endpoint create --region RegionOne volumev3 internal "http://${STORAGE_PUBLIC_IP}:8776/v3/%(project_id)s"
openstack endpoint create --region RegionOne volumev3 admin "http://${STORAGE_PUBLIC_IP}:8776/v3/%(project_id)s"

openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public "http://${CONTROLLER_PUBLIC_IP}:9292"
openstack endpoint create --region RegionOne image internal "http://${CONTROLLER_PUBLIC_IP}:9292"
openstack endpoint create --region RegionOne image admin "http://${CONTROLLER_PUBLIC_IP}:9292"

openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public "http://${CONTROLLER_PUBLIC_IP}:9696"
openstack endpoint create --region RegionOne network internal "http://${CONTROLLER_PUBLIC_IP}:9696"
openstack endpoint create --region RegionOne network admin "http://${CONTROLLER_PUBLIC_IP}:9696"

openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public "http://${CONTROLLER_PUBLIC_IP}:8774/v2.1"
openstack endpoint create --region RegionOne compute internal "http://${CONTROLLER_PUBLIC_IP}:8774/v2.1"
openstack endpoint create --region RegionOne compute admin "http://${CONTROLLER_PUBLIC_IP}:8774/v2.1"

openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public "http://${CONTROLLER_PUBLIC_IP}:8778"
openstack endpoint create --region RegionOne placement internal "http://${CONTROLLER_PUBLIC_IP}:8778"
openstack endpoint create --region RegionOne placement admin "http://${CONTROLLER_PUBLIC_IP}:8778"

openstack service create --name swift --description "OpenStack Object Storage" object-store
openstack endpoint create --region RegionOne object-store public "http://${STORAGE_PUBLIC_IP}:8080/v1/AUTH_%(project_id)s"
openstack endpoint create --region RegionOne object-store internal "http://${STORAGE_PUBLIC_IP}:8080/v1/AUTH_%(project_id)s"
openstack endpoint create --region RegionOne object-store admin "http://${STORAGE_PUBLIC_IP}:8080/v1"

openstack service list
openstack endpoint list
