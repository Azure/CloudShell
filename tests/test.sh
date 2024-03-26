#!/bin/bash

# Run all the unit tests

# make test files read/write by all users
chmod -R a+rw /tests

# If we don't have test user created, create them
id -u csuser 2> /dev/null

if [ $? != 0 ]
then
  echo "Creating user"
  adduser -m --uid 9527 csuser
fi

echo "running root-level tests"
pwsh /tests/root-tests.ps1

pwsh -c "Install-Module Pester -Force -Scope AllUsers"

# Run tests as csuser with an interactive shell to verify the configuration in
# the same environment this imange will be used in. Otherwise, the .bashrc won't
# be sourced and the bash configuration (e.g., environment variables) won't be
# set during the tests.
echo "running tests as csuser"
runuser -u csuser -- /bin/bash -i -c 'pwsh /tests/test.ps1'
