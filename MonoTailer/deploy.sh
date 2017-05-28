#!/bin/bash

target=$2
instances=()

if [ "$1" = "deploy" ] && [ -n "$target" ] ; then
  echo '# Deploying...'
else
  echo '# Dryrun...'
  echo '#'
  echo '#   For actual deploy, run'
  echo '#     "./deploy.sh deploy monotailer" # for monotailer'
  echo '#'
  dryrun=true
fi

if [ -z "$dryrun" ] ; then
  slc build -p
else
  echo "slc build -p"
fi

if [ "$dryrun" = "true" ] || [ "$target" = "monotailer" ] ; then
  echo ''
  echo '# Fetching instance ip addresses...'
  echo ''
  
  for i in `aws ec2 describe-instances --filter Name=tag:pgous,Values=scanner | grep -i instanceid  | awk '{ print $2}' | cut -d',' -f1 | sed -e 's/"//g'`
  do
    instances+=("${i}")
    ip=`aws ec2 describe-instances --instance-ids ${i} | grep -iE "\"PrivateIpAddress\"" | awk '{ print $2 }' | head -1 | cut -d"," -f1 | sed -e 's/"//g'`

    echo "# Deploying to: ${i} (${ip})"
  
    if [ "$dryrun" = "true" ] ; then
      echo slc deploy -s monotailer "http://${SVUSER}:${SVPASS}@${ip}:8701/" ../monotailer-1.0.0.tgz
      echo slc ctl -C "http://${SVUSER}:${SVPASS}@${ip}:8701/" status
    else
      slc deploy -s monotailer "http://${SVUSER}:${SVPASS}@${ip}:8701/" ../monotailer-1.0.0.tgz
      slc ctl -C "http://${SVUSER}:${SVPASS}@${ip}:8701/" status
    fi
  
    echo '' 
  
  done;
fi

echo ''
echo '# Deploy finished.'
