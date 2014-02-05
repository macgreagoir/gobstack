#!/bin/bash
## write out a stackrc file to source for openstack env vars

source ${BASH_SOURCE%/*}/../defaults.sh

grep export ${BASH_SOURCE%/*}/../defaults.sh > ~vagrant/stackrc
sed -i "s/\${CONTROLLER_PUBLIC_IP}/${CONTROLLER_PUBLIC_IP}/" ~vagrant/stackrc
sed -i "s/\${DEMO_TENANT_NAME}/${DEMO_TENANT_NAME}/" ~vagrant/stackrc
chmod 0750 ~vagrant/stackrc
chown vagrant:vagrant ~vagrant/stackrc

