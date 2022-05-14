#!/bin/bash

# wrapper around apt-get install download-only which retries on failure

max_tries=4
count=0
while [ $count -lt $max_tries ]; do 
    ACCEPT_EULA=Y apt-get install --download-only -y -o Dir::Cache="/tmp/shell_packages" -o Dir::Cache::archives="./" $*     
    if [ $? -eq 0 ];  then
        exit 0
    fi
    let count=count+1
done
echo "Too many install attempts, failing"
exit 1
