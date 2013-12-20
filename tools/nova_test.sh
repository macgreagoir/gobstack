#!/bin/bash
## A few tests to check our nova configuraiton
 
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

source ${BASH_SOURCE%/*}/../defaults.sh

echo "Are the compute nodes OK?"
nova-manage service list
echo

echo "Is glance up?"
netstat -ant | grep 9292.*LISTEN
echo

echo "The rabbitmq status:"
rabbitmqctl status
echo

echo "NTP status:"
ntpq -p
echo

echo "MySQL status:"
mysqladmin -uroot -p${MYSQL_ROOT_PASS} status
echo

nova list
nova credentials
