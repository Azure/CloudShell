#!/usr/bin/env pwsh

# install pester then run tests for regular user
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Push-Location /tests
try {
	$config = New-PesterConfiguration
	$config.TestResult.Enabled = $false
	$config.Filter.Tag = "StandardUser" # only run tests tagged StandardUser
	$config.Output.CIFormat = "GithubActions"

	Invoke-Pester -Configuration $config
} finally {
	Pop-Location
}

