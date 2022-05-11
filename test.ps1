# Run the unit tests inside the container

[CmdletBinding()]
param(
    [string]$image = "mariner_cloudshell"
)

$ErrorActionPreference = "Stop"

& docker run --volume $psscriptroot/tests:/tests $image /bin/bash /tests/test.sh