#!/bin/bash

target=$1
instances=()

if [ -n "$target" ] ; then
  echo "# Monitoring $target..."
else
  echo '# Dryrun...'
  echo '#'
  echo '#   For actual monitor, run'
  echo '#     "./monitor.sh <#index>"'
  echo '#     "./monitor.sh 0"'
  echo '#     "./monitor.sh 1"'
  echo '#'
  dryrun=true
fi

echo ''
echo '# Fetching instance ip addresses...'
echo ''

index=0

# scanner
  
for i in `aws ec2 describe-instances --filter Name=tag:pgous,Values=scanner | grep -i instanceid  | awk '{ print $2}' | cut -d',' -f1 | sed -e 's/"//g'`
do
  instances+=("${i}")
  ip=`aws ec2 describe-instances --instance-ids ${i} | grep -iE "\"PrivateIpAddress\"" | awk '{ print $2 }' | head -1 | cut -d"," -f1 | sed -e 's/"//g'`

  echo "#$index To monitor: ${i} (${ip})"

  if [ "$dryrun" = "true" ] ; then
    echo slc ctl -C http://${SVUSER}:${SVPASS}@${ip}:8701/ log-dump monotailer --follow
  else
    if [ "$target" = $index ] ; then
      slc ctl -C http://${SVUSER}:${SVPASS}@${ip}:8701/ log-dump monotailer --follow
    fi
  fi

  echo '' 

  index=$((index+1))

done;
