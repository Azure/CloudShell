#!/usr/bin/env pwsh

# Install pester then run tests for root user
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

cd /tests
Install-Module -Name Pester -Force
Invoke-Pester -Script Root.Tests.ps1