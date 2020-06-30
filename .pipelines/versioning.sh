#!/bin/bash

echo "Entering into the versioning.sh command..."
echo $BUILD_SOURCEVERSION
echo $BUILD_SOURCEBRANCHNAME

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pwsh $DIR/generateVersion.ps1
echo "print env"
env