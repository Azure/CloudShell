#!/bin/bash

# Run the unit tests

# If we don't have test user created, create them
id -u csuser 2> /dev/null

if [ $? != 0 ]
then
  echo "Creating user"
  /tests/setup.sh
fi

echo "running tests as csuser"
runuser -u csuser pwsh /tests/test.ps1