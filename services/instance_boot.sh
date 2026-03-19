#!/bin/bash
## Example boot/creation of an instance
# run this as vagrant@controller0

source ${BASH_SOURCE%/*}/../defaults.sh

## boot a new instance as the non-admin user
# we assume an image and key from our glance and nova installer scripts
IMAGE_ID=$(openstack image list -f value -c ID -c Name | awk '/CirrOS/ {print $1}')
NET_ID=$(openstack network list -f value -c ID -c Name | awk "/${DEMO_TENANT_NAME}-net/ {print \$1}")
# we'll name the instance for the non-admin user
RAND=$(< /dev/urandom tr -dc a-z0-9 | head -c3)
INSTANCE_NAME="${DEMO_TENANT_NAME}_${RAND}"

INSTANCE_ID=$(OS_PROJECT_NAME=${DEMO_TENANT_NAME} OS_USERNAME=${DEMO_USERNAME} \
  openstack server create ${INSTANCE_NAME} \
  --image ${IMAGE_ID} \
  --flavor m1.tiny \
  --key-name vagrant \
  --security-group default \
  --nic net-id=${NET_ID} \
  -f value -c id)

# grab its IP addr
count=3
INSTANCE_IP=''
while [ -z "$INSTANCE_IP" ] && (( count-- > 0 )); do
  echo "I'll try $(( count + 1 )) more times..."
  sleep 5
  INSTANCE_IP=$(openstack server show ${INSTANCE_ID} -f value -c addresses \
    | grep -oP '10\.0\.1\.[0-9]+')
done


## give ourselves a chance to see it boot
if [ -n "$INSTANCE_IP" ]; then
  openstack server show ${INSTANCE_ID}

  # give it a floating IP
  FLOATING_IP=$(OS_PROJECT_NAME=${DEMO_TENANT_NAME} OS_USERNAME=${DEMO_USERNAME} \
    openstack floating ip create ext-net -f value -c floating_ip_address)
  if [ -n "$FLOATING_IP" ]; then
    openstack server add floating ip ${INSTANCE_NAME} ${FLOATING_IP}
  fi

  ## create a volume named for the instance
  # delete any old ones, though there should be none
  for id in $(openstack volume list -f value -c ID -c Name \
    | awk "/${INSTANCE_NAME}/ {print \$1}"); do
    openstack volume delete $id
  done

  # create a 1GB volume
  VOLUME_ID=$(openstack volume create \
    --size 1 \
    --description "${INSTANCE_NAME}" \
    ${INSTANCE_NAME} \
    -f value -c id)

  # attach the volume, letting the instance choose local device (auto)
  sleep 20 # the instance needs time to build
  openstack server add volume ${INSTANCE_ID} ${VOLUME_ID}
  openstack volume show ${VOLUME_ID}

  echo "Waiting for ${INSTANCE_NAME} to boot..."
  openstack console url show --novnc ${INSTANCE_NAME}
  sleep 20
  echo "Whistle a happy tune and give ssh a chance to start on ${FLOATING_IP}..."
  echo
  echo "...then \"ssh -o 'IdentityFile ~/.ssh/vagrant.pem' cirros@${FLOATING_IP}\""
  echo
else
  echo "No IP address was found for instance ${INSTANCE_NAME} (${INSTANCE_ID})"
fi
