# This script is run at image build time to install and configure the PowerShell modules that are preinstalled with Cloud Shell

param(
    [Parameter(Mandatory = $True, Position = 0)]
    [ValidateSet("Base", "Top")]
    [System.String]
    $Image
)

$ProgressPreference = 'SilentlyContinue' # Suppresses progress, which doesn't render correctly in docker

# PowerShellGallery PROD site
$prodGallery = 'https://www.powershellgallery.com/api/v2'

$script:pscloudshellBlob = $null                            # Version folder for the pscloudshell blob storage
$shareModulePath = ([System.Management.Automation.Platform]::SelectProductNameForDirectory('SHARED_MODULES'))
$modulePath = if ($shareModulePath) {$shareModulePath}else {Microsoft.PowerShell.Management\Join-Path $PSHOME 'Modules'}
$script:dockerfileDataObject = $null                        # json object holding data from dockerfile.data.json file


# In almost all cases, Cloud Shell pulls modules from the regular PowerShell Gallery or preview gallery at build time.
# In a few legacy cases, we include modules which are not intended for broader use. These are pulled from an Azure storage
# account using the code below.

# PSCloudShell depends on files under Azure blob storage. The name of 'folder' (Azure container) is the version number.
# Read the version info from the Dockerfile.Data.json. In such way, only the Dockerfile.Data.json to be updated if there is
# any version changes.
function Get-DockerfileData {
    $dockerFileData = Microsoft.PowerShell.Management\Join-Path $PSScriptRoot -ChildPath 'Dockerfile.Data.json'
    Write-Output "Calling Get-Content from $dockerFileData"
    $script:dockerfileDataObject = Microsoft.PowerShell.Management\Get-Content $dockerFileData | Microsoft.PowerShell.Utility\ConvertFrom-Json
    if (-not $script:dockerfileDataObject) {
        throw "Error while reading $dockerFileData file."
    }
    $pscloudshellVer = $script:dockerfileDataObject.PSCloudShellVersion
    Write-Output "pscloudshellVersion= $pscloudshellVer;"
}

# Install Azure and AzureAD (Active Directory) modules
# This function replaces the old poshtestgallery issue
function Install-AzAndAzAdModules {
    Write-Output "Install-AzAndAdModules.."
    mkdir temp
    curl -o az-cmdlets.tar.gz -sSL "https://azpspackage.blob.core.windows.net/release/Az-Cmdlets-latest.tar.gz"
    tar -xf az-cmdlets.tar.gz -C temp
    rm az-cmdlets.tar.gz
    cd temp

    cp /usr/cloudshell/powershell/pkgs/azuread.standard.preview.0.0.0.10.nupkg ./AzureAD.Standard.Preview.nupkg

    $SourceLocation = $PSScriptRoot
    Write-Output "Source Location: $SourceLocation"

    $gallery = [guid]::NewGuid().ToString()
    Write-Output "Registering temporary repository $gallery with InstallationPolicy Trusted..."
    Register-PSRepository -Name $gallery -SourceLocation $($pwd.providerPath) -PackageManagementProvider NuGet -InstallationPolicy Trusted

    try {
        Write-Output "Installing Az..."
        Install-Module -Name Az -Repository $gallery -Scope AllUsers -AllowClobber -Force
        Write-Output "Installing AzureAD.Standard.Preview..."
        Install-Module -Name "AzureAD.Standard.Preview" -Repository $gallery -Scope AllUsers -AllowClobber -Force
    }
    finally {
        Write-Output "Unregistering gallery $gallery..."
        Unregister-PSRepository -Name $gallery
    }

    cd ..
    rm -rf temp

}

# Download files from the PSCloudShell Azure storage blob
function Install-PSCloudShellFile {
    param(
        [string]$Source,
        [string]$FileName,
        [string]$Destination,
        [string]$FileHash
    )

    $FullPath = Microsoft.PowerShell.Management\Join-Path -Path $Source -ChildPath $FileName
    Write-Output "URL= $script:pscloudshellBlob/$FileName; FullPath= $FullPath; Destination=$Destination"
    Microsoft.PowerShell.Utility\Invoke-WebRequest -Uri "$script:pscloudshellBlob/$FileName" -UseBasicParsing -OutFile $FullPath
    $hash = (Microsoft.PowerShell.Utility\Get-FileHash $FullPath).Hash
    if ($hash -eq $FileHash) {
        Microsoft.PowerShell.Archive\Expand-Archive -Path $FullPath -DestinationPath $Destination -Verbose -Force
    }
    else {
        throw "Hash mismatch for $FullPath. Expected: $FileHash Actual:$hash."
    }
}

try {
    # Get the pscloudshell version info and Az version info from from the ..\..\Windows\Dockerfile.Data.json
    Get-DockerfileData

    # Set up repo as trusted to avoid prompts
    PowerShellGet\Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    $prodAllUsers = @{Repository = "PSGallery"; Scope = "AllUsers"}

    if ($image -eq "Base") {
        Write-Output "Installing modules from production gallery"
        PowerShellGet\Install-Module -Name SHiPS @prodAllUsers
        PowerShellGet\Install-Module -Name SQLServer -MaximumVersion $script:dockerfileDataObject.SQLServerModuleMaxVersion @prodAllUsers
        PowerShellGet\Install-Module -Name MicrosoftPowerBIMgmt -MaximumVersion $script:dockerfileDataObject.PowerBIMaxVersion @prodAllUsers
        PowerShellGet\Install-Module -Name MicrosoftTeams @prodAllUsers

        # MS Graph packages
        PowerShellGet\Install-Module -Name Microsoft.Graph.Authentication @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Graph.Users.Actions @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Graph.Users.Functions @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Graph.Groups @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Graph.Identity.Governance @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Graph.Identity.SignIns @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Graph.Applications @prodAllUsers

        # Microsoft Entra PowerShell packages
        PowerShellGet\Install-Module -Name Microsoft.Entra.Authentication @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Entra.Users @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Entra.Groups @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Entra.DirectoryManagement @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Entra.Governance @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Entra.SignIns @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Entra.Applications @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.Entra.Reports @prodAllUsers
    }
    else {
        # Installing modules from Azure Powershell and AzureAD
        Write-Output "Installing modules from Azure Powershell and AzureAD"
        Install-AzAndAzAdModules

        # Install modules from PSGallery
        Write-Output "Installing modules from production gallery"
        PowerShellGet\Install-Module -Name AzurePSDrive @prodAllUsers
        PowerShellGet\Install-Module -Name GuestConfiguration -MaximumVersion $script:dockerfileDataObject.GuestConfigurationMaxVersion -ErrorAction SilentlyContinue @prodAllUsers
        PowerShellGet\Install-Module -Force PSReadLine @prodAllUsers
        PowerShellGet\Install-Module -Name Az.Tools.Predictor @prodAllUsers
        PowerShellGet\Install-Module -Name ExchangeOnlineManagement @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.PowerShell.SecretManagement @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.PowerShell.SecretStore @prodAllUsers

        # With older base image builds, teams 1.1.6 is already installed
        if (Get-Module MicrosoftTeams -ListAvailable) {
            # For some odd reason, Update-Module was creating the MicrosoftTeams module twice with different version numbers.
            # Uninstalling and then installing it again was the only way to keep it as one module.
            Uninstall-Module MicrosoftTeams -Force
            PowerShellGet\Install-Module -Name MicrosoftTeams @prodAllUsers
        } else {
            PowerShellGet\Install-Module -Name MicrosoftTeams @prodAllUsers
        }

        # Install PSCloudShell modules
        $tempDirectory = Microsoft.PowerShell.Management\Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
        $null = Microsoft.PowerShell.Management\New-Item -ItemType Directory $tempDirectory -ErrorAction SilentlyContinue

        if (Microsoft.PowerShell.Management\Test-Path $tempDirectory) {
            Write-Output ('Temp Directory: {0}' -f $tempDirectory)
        }

        # Copy the startup script to the all-users profile
        $psStartupScript = Microsoft.PowerShell.Management\Join-Path $PSHOME 'PSCloudShellStartup.ps1'
        Microsoft.PowerShell.Management\Copy-Item -Path $PSScriptRoot\PSCloudShellStartup.ps1 -Destination $psStartupScript

        Write-Output "Installing powershell profile to $($PROFILE.AllUsersAllHosts)"
        Microsoft.PowerShell.Management\Copy-Item -Path $psStartupScript -Destination $PROFILE.AllUsersAllHosts -Verbose
        Write-Output "Installed powershell profile."

        # Update PowerShell Core help files in the image, ensure any errors that result in help not being updated does not interfere with the build process
        # We want the image to have latest help files when shipped.
        Write-Output "Updating help files."
        $null = Microsoft.PowerShell.Core\Update-Help -Scope AllUsers -Force -ErrorAction Ignore
        Write-Output "Updated."
    }

    Write-Output "All modules installed:"
    Write-Output (Get-InstalledModule | Sort-Object Name | Select-Object Name, Version, Repository)
}
finally {
    # Clean-up the PowerShell Gallery registration settings
    PowerShellGet\Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted -ErrorAction Ignore
    if ($tempDirectory -and (Microsoft.PowerShell.Management\Test-Path $tempDirectory)) {
        Microsoft.PowerShell.Management\Remove-Item $tempDirectory -Force -Recurse -ErrorAction Ignore
    }
}
