#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"
cd /tests
Install-Module -Name Pester -Force
Invoke-Pester