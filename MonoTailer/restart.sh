#!/bin/bash

target=$2
instances=()

if [ "$1" = "restart" ] && [ -n "$target" ] ; then
  echo '# Restarting...' 
else
  echo '# Dryrun...'
  echo '#'
  echo '#   For actual restart, run'
  echo '#     "./restart.sh restart monotailer" # for monotailer'
  echo '#'
  dryrun=true
fi

if [ "$dryrun" = "true" ] || [ "$target" = "monotailer" ] || [ "$target" = "all" ] ; then
  echo ''
  echo '# Fetching instance ip addresses...'
  echo ''
  
  for i in `aws ec2 describe-instances --filter Name=tag:pgous,Values=scanner | grep -i instanceid  | awk '{ print $2}' | cut -d',' -f1 | sed -e 's/"//g'`
  do
    instances+=("${i}")
    ip=`aws ec2 describe-instances --instance-ids ${i} | grep -iE "\"PrivateIpAddress\"" | awk '{ print $2 }' | head -1 | cut -d"," -f1 | sed -e 's/"//g'`

    echo "# Restarting: ${i} (${ip})"
  
    if [ "$dryrun" = "true" ] ; then
      echo slc ctl -C "http://${SVUSER}:${SVPASS}@${ip}:8701/" cluster-restart monotailer
    else
      slc ctl -C "http://${SVUSER}:${SVPASS}@${ip}:8701/" cluster-restart monotailer
    fi
  
    echo '' 
  
  done;
fi

echo ''
echo '# Restart finished.'
