<#
.SYNOPSIS
Prepares the PowerShell environment for optimized start-up to enable faster user connections at runtime.

.DESCRIPTION
This is a performance optimization to enable PowerShell modules to load faster during user connections to a shell. We pre-load modules in a PowerShell process to load them into the container's memory. The idea is that it will enable the modules to load quicker when the user terminal process imports them.

.EXAMPLE
Start a PowerShell process to load the modules and then exit.
.\Invoke-PreLoadModule.ps1
#>

# AzurePSDrive requires Azure authentication so it cannot be preloaded.
$moduleList = @(
    "Microsoft.PowerShell.Management",
    "PSCloudShellUtility",
    "SHiPS",
    "AzurePSDrive",
    "MicrosoftPowerBIMgmt",
    "Az",
    "GuestConfiguration",
    "Microsoft.PowerShell.UnixCompleters",
    "Microsoft.PowerShell.SecretManagement",
    "Microsoft.PowerShell.SecretStore"
)

# set SkipAzInstallationChecks to avoid az check for AzInstallationChecks.json
[System.Environment]::SetEnvironmentVariable('SkipAzInstallationChecks', $true)

foreach ($module in $moduleList) {
    try {
        Write-Output "Importing $module..."
        Import-Module $module -Force
    }
    catch {
        Write-Error -Message "Unexpected error encountered when importing $module. Exception = $($_.Exception)."
    }
}
