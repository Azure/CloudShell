param(
    [Parameter(Mandatory=$True, Position=0)]
    [ValidateSet(“Base”,”Top”)]
    [System.String]
    $Image
)

$ProgressPreference    = 'SilentlyContinue' # Suppresses progress, which doesn't render correctly in docker
$intGallery  = 'https://www.poshtestgallery.com/api/v2' # Pick-up Azure modules from int gallery due to sequence PSCloudShell and Az release to public correctly
$prodGallery = 'https://www.powershellgallery.com/api/v2'   # PowerShellGallery PROD site
$script:pscloudshellBlob = $null                            # Version folder for the pscloudshell blob storage
$shareModulePath =  ([System.Management.Automation.Platform]::SelectProductNameForDirectory('SHARED_MODULES'))
$modulePath = if($shareModulePath){$shareModulePath}else{Microsoft.PowerShell.Management\Join-Path $PSHOME 'Modules'}
$script:dockerfileDataObject = $null                        # json object holding data from dockerfile.data.json file

# PSCloudShell depends on files under Azure blob storage. The name of 'folder' (Azure container) is the version number.
# Read the version info from the ..\..\Windows\Dockerfile.Data.json. In such way, only the Dockerfile.Data.json to be updated if there is
# any version changes.
function Get-DockerfileData
{
    $dockerFileData = Microsoft.PowerShell.Management\Join-Path $PSScriptRoot -ChildPath 'Dockerfile.Data.json'
    Write-Output "Calling Get-Content from $dockerFileData"
    $script:dockerfileDataObject=Microsoft.PowerShell.Management\Get-Content $dockerFileData | Microsoft.PowerShell.Utility\ConvertFrom-Json
    if(-not $script:dockerfileDataObject)
    {
        throw "Error while reading $dockerFileData file."
    }   
    $pscloudshellVer =$script:dockerfileDataObject.PSCloudShellVersion
    $script:pscloudshellBlob ="https://pscloudshellbuild.blob.core.windows.net/$pscloudshellVer"
    Write-Output "pscloudshellVersion= $pscloudshellVer; pscloudshellBlob=$script:pscloudshellBlob"
}

# Download files from the PSCloudShell Azure storage blob
function Install-PSCloudShellFile
{
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
    if ($hash -eq $FileHash)
    {
        Microsoft.PowerShell.Archive\Expand-Archive -Path $FullPath -DestinationPath $Destination -Verbose -Force
    }
    else
    {
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

    if($image -eq "Base"){
        Write-Output "Installing modules from production gallery"
        PowerShellGet\Install-Module -Name SHiPS @prodAllUsers    
        PowerShellGet\Install-Module -Name SQLServer -MaximumVersion $script:dockerfileDataObject.SQLServerModuleMaxVersion @prodAllUsers
        PowerShellGet\Install-Module -Name MicrosoftPowerBIMgmt -MaximumVersion $script:dockerfileDataObject.PowerBIMaxVersion @prodAllUsers
        PowerShellGet\Install-Module -Name MicrosoftTeams @prodAllUsers   
        Write-Output "All modules installed:"
        Write-Output (Get-InstalledModule) 
    } else {
        # Install modules from the PowerShell Test Gallery
        Write-Output "Installing modules from test gallery"
        PowerShellGet\Install-Module -Name Az -MaximumVersion $script:dockerfileDataObject.AzMaxVersion @intAllUsers
        PowerShellGet\Install-Module -Name AzureAD.Standard.Preview -MaximumVersion $script:dockerfileDataObject.AzureADStandardMaxVersion @intAllUsers

        # Install modules from PSGallery
        Write-Output "Installing modules from production gallery"    
        PowerShellGet\Install-Module -Name AzurePSDrive @prodAllUsers   
        PowerShellGet\Install-Module -Name Az.GuestConfiguration -MaximumVersion $script:dockerfileDataObject.AzGuestConfigurationMaxVersion -ErrorAction SilentlyContinue @prodAllUsers
        PowerShellGet\Install-Module -Name Microsoft.PowerShell.UnixCompleters @prodAllUsers

        Write-Output "All modules installed:"
        Write-Output (Get-InstalledModule)

        # Install PSCloudShell modules
        $tempDirectory = Microsoft.PowerShell.Management\Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
        $null = Microsoft.PowerShell.Management\New-Item -ItemType Directory $tempDirectory -ErrorAction SilentlyContinue

        if(Microsoft.PowerShell.Management\Test-Path $tempDirectory)
        {
            Write-Output ('Temp Directory: {0}' -f $tempDirectory)

            # Install the PSCloudShellUtility, Exchange modules from the Azure storage
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
        $null = Microsoft.PowerShell.Core\Update-Help -Scope AllUsers -Force -Verbose -ErrorAction Ignore
        Write-Output "Updated."
    }
}
finally {
    # Clean-up the PowerShell Gallery registration settings
    PowerShellGet\Unregister-PSRepository -Name intGallery -ErrorAction Ignore
    PowerShellGet\Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted -ErrorAction Ignore
    if ($tempDirectory -and (Microsoft.PowerShell.Management\Test-Path $tempDirectory))
    {
        Microsoft.PowerShell.Management\Remove-Item $tempDirectory -Force -Recurse -ErrorAction Ignore
    }
}
