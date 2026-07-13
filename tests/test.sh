#!/bin/bash
set -euo pipefail

# Run all the unit tests

# make test files read/write by all users
chmod -R a+rw /tests

# If we don't have test user created, create them
if ! id -u csuser &>/dev/null; then
  echo "Creating user"
  adduser -m --uid 9527 csuser
fi

echo "running root-level tests"
pwsh /tests/root-tests.ps1

	# Pester is also installed in `root-tests.ps1` - make sure that is using the same version as here.
pwsh -c "Install-Module Pester -MinimumVersion 6.0.0 -MaximumVersion 6.999.999 -Force -Scope AllUsers"

echo "running tests as csuser"
runuser -u csuser pwsh /tests/test.ps1

# Tests if the maven installation is working.
runuser -u csuser bash /tests/test-mvn.sh
