#!/bin/bash
## Example boot of demo instance
# run this as the vagrant@controller0
 
source ${BASH_SOURCE%/*}/defaults.sh
# ...but we want to be the demo user
unset OS_USERNAME
export OS_USERNAME=demo

# we assume an image and key from our glance and nova installer scripts
IMAGE_ID=`nova image-list | awk '/\ CirrOS\ / {print $2}'`
RAND=`< /dev/urandom tr -dc a-z0-9 | head -c3`
DEMO_INSTANCE_ID=`nova boot demo_instance_${RAND} --image ${IMAGE_ID} --flavor 1 --key_name vagrant \
  | awk '$2 == "id" {print $4}'`

count=5
INSTANCE_IP=''
while [ -z "$INSTANCE_IP" ] &&  (( count-- > 0 )); do
  echo "I'll try $(( count + 1 )) more times..."
  INSTANCE_IP=`nova show $DEMO_INSTANCE_ID \
    | awk '/private network.*172/ {print}' | sed 's|.*\(172\.20\.10\.[[:digit:]+]\).*|\1|'`
  sleep 5
done

nova show $DEMO_INSTANCE_ID

if [ -z "$INSTANCE_IP" ]; then
  ping -c 9 ${INSTANCE_IP}
  echo "Whistle a happy tune and give ssh a chance to start on ${INSTANCE_IP}..."
  echo "ssh cirros@${INSTANCE_IP} with passwd 'cubswin:)'"
fi

