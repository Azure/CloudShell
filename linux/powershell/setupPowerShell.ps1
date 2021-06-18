# This script is run at image build time to install and configure the PowerShell modules that are preinstalled with Cloud Shell

param(
    [Parameter(Mandatory = $True, Position = 0)]
    [ValidateSet("Base", "Top")]
    [System.String]
    $Image
)

$ProgressPreference = 'SilentlyContinue' # Suppresses progress, which doesn't render correctly in docker

# The preview version of the PowerShell gallery. We pick up Azure modules from there because they are released to that location shortly before
# being released to the main gallery. This allows us to build the Cloud Shell image and deploy it to production at the same time that the modules
# can be downloaded from the main gallery
$intGallery = 'https://www.poshtestgallery.com/api/v2' 

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
    $script:pscloudshellBlob = "https://pscloudshellbuild.blob.core.windows.net/$pscloudshellVer"
    Write-Output "pscloudshellVersion= $pscloudshellVer; pscloudshellBlob=$script:pscloudshellBlob"
}

# A build of LibMI.so compatible with OpenSSL 1.1 is stored in the blob. This has not yet been tested in any other
# situation than running in Cloud Shell
function Install-LibMIFile {
    $libmiversion = $script:dockerfileDataObject.libmiversion
    $FileHash = $script:dockerfileDataObject.libmifilehash
    $libmiBlob = "https://pscloudshellbuild.blob.core.windows.net/$libmiversion/a/debian10-libmi/libmi.so"
    $FullPath = "/opt/microsoft/powershell/7/libmi.so"
    Write-Output "Updating libmi.so with $($libmiBlob)"
    Microsoft.PowerShell.Utility\Invoke-WebRequest -Uri $libmiBlob -UseBasicParsing -OutFile $FullPath
    $hash = (Microsoft.PowerShell.Utility\Get-FileHash $FullPath).Hash
    if ($hash -ne $FileHash) {
        throw "Hash mismatch for $FullPath. Expected: $FileHash Actual:$hash."
    }

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
    PowerShellGet\Register-PSRepository -Name intGallery -SourceLocation $intGallery -InstallationPolicy Trusted
    $intAllUsers = @{Repository = "intGallery"; Scope = "AllUsers"}
    $prodAllUsers = @{Repository = "PSGallery"; Scope = "AllUsers"}

    if ($image -eq "Base") {
        Write-Output "Installing modules from production gallery"
        PowerShellGet\Install-Module -Name SHiPS @prodAllUsers    
        PowerShellGet\Install-Module -Name SQLServer -MaximumVersion $script:dockerfileDataObject.SQLServerModuleMaxVersion @prodAllUsers
        PowerShellGet\Install-Module -Name MicrosoftPowerBIMgmt -MaximumVersion $script:dockerfileDataObject.PowerBIMaxVersion @prodAllUsers
        PowerShellGet\Install-Module -Name MicrosoftTeams @prodAllUsers           
    }
    else {
        # update libmi.so
        Write-Output "Updating libmi.so"
        Install-LibMIFile

        # Install modules from the PowerShell Test Gallery
        Write-Output "Installing modules from test gallery"
        PowerShellGet\Install-Module -Name Az -MaximumVersion $script:dockerfileDataObject.AzMaxVersion @intAllUsers
        PowerShellGet\Install-Module -Name AzureAD.Standard.Preview -MaximumVersion $script:dockerfileDataObject.AzureADStandardMaxVersion @intAllUsers

        # Install modules from PSGallery
        Write-Output "Installing modules from production gallery"    
        PowerShellGet\Install-Module -Name AzurePSDrive @prodAllUsers   
        PowerShellGet\Install-Module -Name Az.GuestConfiguration -MaximumVersion $script:dockerfileDataObject.AzGuestConfigurationMaxVersion -ErrorAction SilentlyContinue @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.PowerShell.UnixCompleters @prodAllUsers
        PowerShellGet\Install-Module -AllowPreRelease -Force PSReadLine -Repository PSGallery # get psreadline beta
        PowerShellGet\Install-Module -Name Az.Tools.Predictor -Repository PSGallery
        PowerShellGet\Install-Module -Name ExchangeOnlineManagement -RequiredVersion 2.0.5 -Force

        # With older base image builds, teams 1.1.6 is already installed 
        if (Get-Module MicrosoftTeams -ListAvailable) {
            Update-Module MicrosoftTeams -Force -Scope AllUsers
        } else {
            PowerShellGet\Install-Module -Name MicrosoftTeams @prodAllUsers     
        }

        # Install PSCloudShell modules
        $tempDirectory = Microsoft.PowerShell.Management\Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
        $null = Microsoft.PowerShell.Management\New-Item -ItemType Directory $tempDirectory -ErrorAction SilentlyContinue

        if (Microsoft.PowerShell.Management\Test-Path $tempDirectory) {
            Write-Output ('Temp Directory: {0}' -f $tempDirectory)

            # Install the Exchange modules from the Azure storage
            Install-PSCloudShellFile -Source $tempDirectory -FileName 'EXOPSSessionConnector.zip' -Destination $modulePath -FileHash $script:dockerfileDataObject.ExoConnectorFileHash
            Write-Output "Installed Exchange Package."
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
    PowerShellGet\Unregister-PSRepository -Name intGallery -ErrorAction Ignore
    PowerShellGet\Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted -ErrorAction Ignore
    if ($tempDirectory -and (Microsoft.PowerShell.Management\Test-Path $tempDirectory)) {
        Microsoft.PowerShell.Management\Remove-Item $tempDirectory -Force -Recurse -ErrorAction Ignore
    }
}
