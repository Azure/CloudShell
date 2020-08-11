#!/bin/bash

shopt -e

pushd "$(dirname "$0")"

docker build -t base_cloudshell -f linux/base.Dockerfile .
docker build -t tools_cloudshell --build-arg IMAGE_LOCATION=base_cloudshell -f linux/tools.Dockerfile . 
docker run --volume $(pwd)/tests:/tests tools_cloudshell pwsh -c "cd /tests; Install-Module -Name Pester -Force; Invoke-Pester -EnableExit"
