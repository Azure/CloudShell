#!/usr/bin/env bash

set -euo pipefail

echo "Testing maven installation"

pushd $(mktemp -d)
mvn archetype:generate -DgroupId=com.example -DartifactId=myapp -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false
popd
