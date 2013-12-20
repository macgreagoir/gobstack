#!/bin/bash
## Example boot/creation of an instance
# run this as vagrant@controller0
 
source ${BASH_SOURCE%/*}/../defaults.sh
# ...but we want to be the tenant's non-admin user
unset OS_USERNAME
export OS_USERNAME=$OS_TENANT_NAME

# we assume an image and key from our glance and nova installer scripts
IMAGE_ID=`nova image-list | awk '/\ CirrOS\ / {print $2}'`
# we'll name the instance for the user
RAND=`< /dev/urandom tr -dc a-z0-9 | head -c3`
INSTANCE_NAME="${OS_USERNAME}_${RAND}"
INSTANCE_ID=`nova boot ${INSTANCE_NAME} --image ${IMAGE_ID} --flavor 1 --key_name vagrant \
  | awk '$2 == "id" {print $4}'`

count=3
INSTANCE_IP=''
while [ -z "$INSTANCE_IP" ] &&  (( count-- > 0 )); do
  echo "I'll try $(( count + 1 )) more times..."
  sleep 5
  INSTANCE_IP=`nova show $INSTANCE_ID \
    | awk '/private network.*172/ {print}' | sed 's|.*\(172\.20\.10\.[[:digit:]+]\).*|\1|'`
done

nova show $INSTANCE_ID

if [ -n "$INSTANCE_IP" ]; then
  echo "Waiting for ${INSTANCE_NAME} to boot..."
  sleep 20
  ping -c 9 ${INSTANCE_IP}
  echo "Whistle a happy tune and give ssh a chance to start on ${INSTANCE_IP}..."
  echo "ssh cirros@${INSTANCE_IP} with passwd 'cubswin:)'"
fi

