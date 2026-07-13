#!/usr/bin/env pwsh

# Install pester then run tests for root user
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Push-Location /tests
try {
	Install-Module -Name Pester -MinimumVersion 6.0.0 -MaximumVersion 6.999.999 -Force

	$config = New-PesterConfiguration
	$config.TestResult.Enabled = $false
	$config.Filter.Tag = "RootUser" # only run tests tagged StandardUser
	$config.Output.CIFormat = "GithubActions"

	Invoke-Pester -Configuration $config
} finally {
	Pop-Location
}