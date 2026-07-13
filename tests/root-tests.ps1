#!/usr/bin/env pwsh

# Install pester then run tests for root user
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Push-Location /tests
try {
	# Pester is also installed in `test.sh` - make sure that is using the same version as here.
	Install-Module -Name Pester -MinimumVersion 6.0.0 -MaximumVersion 6.999.999 -Force

	$config = New-PesterConfiguration
	$config.TestResult.Enabled = $false
	$config.Filter.Tag = "RootUser" 
	$config.Output.CIFormat = "GithubActions"

	Invoke-Pester -Configuration $config
} finally {
	Pop-Location
}