#!/bin/bash
## Install and configure MariaDB

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

if [[ -z `ip addr | grep "${CONTROLLER_PUBLIC_IP}"` ]]; then
  echo "This script expects an interface with ${CONTROLLER_PUBLIC_IP}" 1>&2
  exit 1
fi

# pre-seed debconf for non-interactive install
echo "mariadb-server mysql-server/root_password password ${MYSQL_ROOT_PASS}
mariadb-server mysql-server/root_password seen true
mariadb-server mysql-server/root_password_again password ${MYSQL_ROOT_PASS}
mariadb-server mysql-server/root_password_again seen true
"  | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive
apt-get install -y mariadb-server python3-pymysql

# OpenStack requires utf8 and the controller IP as bind address
MARIADB_CONF=/etc/mysql/mariadb.conf.d/50-server.cnf
if [ -z "`grep character-set-server.*utf8 ${MARIADB_CONF}`" ]; then
  sed -i "/^\[mysqld\]/ a \
collation-server = utf8_general_ci\ncharacter-set-server = utf8" \
  ${MARIADB_CONF}
fi
sed -i "s/^bind\-address.*/bind\-address = ${CONTROLLER_PUBLIC_IP}/" \
  ${MARIADB_CONF}
service mariadb restart

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON *.* TO root@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}' WITH GRANT OPTION;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON *.* TO root@'${CONTROLLER_PUBLIC_IP}' IDENTIFIED BY '${MYSQL_ROOT_PASS}' WITH GRANT OPTION;"

# clean-up for added security
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DROP USER IF EXISTS ''@'localhost';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DROP USER IF EXISTS ''@'$(hostname)';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DROP USER IF EXISTS 'root'@'%';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DELETE FROM mysql.db WHERE Db LIKE 'test%';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DROP DATABASE IF EXISTS test;"

mysqladmin -uroot -p${MYSQL_ROOT_PASS} flush-privileges
mysqladmin -uroot -p${MYSQL_ROOT_PASS} status
