#!/bin/bash
## A few tests to check our nova configuration

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

echo "Are the compute nodes OK?"
openstack compute service list
echo

echo "Is glance up?"
netstat -ant | grep 9292.*LISTEN
echo

echo "The rabbitmq status:"
rabbitmqctl status
echo

echo "Chrony status:"
chronyc tracking
echo

echo "MariaDB status:"
mysqladmin -uroot -p${MYSQL_ROOT_PASS} status
echo

openstack server list
