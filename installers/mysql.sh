#!/bin/bash
## Install and configure MySQL

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
echo "mysql-server-5.5 mysql-server/root_password password ${MYSQL_ROOT_PASS}
mysql-server-5.5 mysql-server/root_password seen true
mysql-server-5.5 mysql-server/root_password_again password ${MYSQL_ROOT_PASS}
mysql-server-5.5 mysql-server/root_password_again seen true
"  | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive
apt-get install -y mysql-server python-mysqldb
# Icehouse needs utf8
if [ -z "`grep character-set-server.*utf8 /etc/mysql/my.cnf`" ]; then
  sed -i "/\[mysqld\]/ a \
collation-server = utf8_general_ci\ninit-connect='SET NAMES utf8'\ncharacter-set-server = utf8" \
  /etc/mysql/my.cnf
fi
sed -i "s/^bind\-address.*/bind\-address = ${CONTROLLER_PUBLIC_IP}/" \
  /etc/mysql/my.cnf
service mysql restart

mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON *.* TO root@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}' WITH GRANT OPTION;"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "GRANT ALL ON *.* TO root@'${CONTROLLER_PUBLIC_IP}' IDENTIFIED BY '${MYSQL_ROOT_PASS}' WITH GRANT OPTION;"

# clean-up for added security
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DROP USER ''@'localhost', ''@'$(hostname)';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DROP USER 'root'@'%';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DELETE FROM mysql.db WHERE Db LIKE 'test%';"
mysql -uroot -p${MYSQL_ROOT_PASS} -e \
  "DROP DATABASE test;"

mysqladmin -uroot -p${MYSQL_ROOT_PASS} flush-privileges
mysqladmin -uroot -p${MYSQL_ROOT_PASS} status

