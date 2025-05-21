Import-Module Microsoft.Graph.Applications -Force -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -Force -ErrorAction Stop

# Verify modules were loaded successfully
$appsModule = Get-Module Microsoft.Graph.Applications
$groupsModule = Get-Module Microsoft.Graph.Groups
$authModule = Get-Module Microsoft.Graph.Authentication

Write-Host "Microsoft.Graph.Authentication version: $($authModule.Version.ToString())"
Write-Host "Microsoft.Graph.Applications version: $($appsModule.Version.ToString())"
Write-Host "Microsoft.Graph.Groups version: $($groupsModule.Version.ToString())"

# This is what we want to check in our test
if ($appsModule.Version.ToString() -eq $authModule.Version.ToString() -and 
    $groupsModule.Version.ToString() -eq $authModule.Version.ToString()) {
    Write-Host "Test passed - all modules have the same version"
    exit 0
} else {
    Write-Host "Test failed - module versions don't match"
    exit 1
}