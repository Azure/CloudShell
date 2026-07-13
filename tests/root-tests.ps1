#!/usr/bin/env pwsh

# Install pester then run tests for root user
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Push-Location /tests
try {
	Install-Module -Name Pester -Force
	Invoke-Pester -CI -Path Root.Tests.ps1
} finally {
	Pop-Location
}