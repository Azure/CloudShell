#!/usr/bin/env pwsh

# install pester then run tests for regular user
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

cd /tests
Invoke-Pester -CI -Script PSinLinuxCloudShellImage.Tests.ps1
