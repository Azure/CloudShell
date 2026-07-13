#!/usr/bin/env pwsh

# install pester then run tests for regular user
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

cd /tests
Invoke-Pester -CI -Path PSinLinuxCloudShellImage.Tests.ps1
