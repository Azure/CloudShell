#!/bin/bash

# wrapper around tdnf install which retries on failure

max_tries=4
count=0
while [ $count -lt $max_tries ]; do
    ACCEPT_EULA=Y tdnf install -y $*
    if [ $? -eq 0 ];  then
        exit 0
    fi
    let count=count+1
done
echo "Too many install attempts, failing"
exit 1