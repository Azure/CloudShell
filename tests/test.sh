#!/bin/bash

# Run the unit tests

# make test files read/write by all users
chmod -R a+rw /tests

# If we don't have test user created, create them
id -u csuser 2> /dev/null

if [ $? != 0 ]
then
  echo "Creating user"
  adduser --disabled-login --gecos "" --uid 9527 csuser
fi

echo "running tests as csuser"
runuser -u csuser pwsh /tests/test.ps1