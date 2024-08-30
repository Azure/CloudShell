# Startupscript for PowerShell Cloud Shell

#region Script Variables
$script:Startuptime = [System.DateTime]::Now
$script:AzureADModuleName = 'AzureAD.Standard.Preview'

# Set SkipAzInstallationChecks to avoid az check for AzInstallationChecks.json
[System.Environment]::SetEnvironmentVariable('SkipAzInstallationChecks', $true)

# Get SkipMSIAuth for local testing. If skipped, auth will be taken care of by testing script.
$script:SkipMSIAuth = [System.Environment]::GetEnvironmentVariable('SkipMSIAuth')

Microsoft.PowerShell.Core\Import-Module -Name PSCloudShellUtility
$script:PSCloudShellUtilityModuleInfo = Microsoft.PowerShell.Core\Get-Module PSCloudShellUtility

$script:CloudEnvironmentMap = @{
    PROD = 'AzureCloud';
    Fairfax = 'AzureUSGovernment';
    Mooncake = 'AzureChinaCloud';
    BlackForest = 'AzureGermanCloud';
    dogfood = 'dogfood';
    USNat = 'AzureUSGovernment2';
    USSec = 'AzureUSGovernment3'
}

# For the Az.Tools.Predictor
PSReadline\Set-PSReadLineOption -Colors @{ InLinePrediction = '#8d8d8d'}
Microsoft.PowerShell.Core\Import-Module Az.Tools.Predictor -Force

# Using the new set of az cmdlets
Microsoft.PowerShell.Core\Import-Module Az.Accounts
Az.Accounts\Enable-AzureRmAlias

# On Linux, we are not loading the profile from the clouddrive since we are already mounted on the Linux OS image: \clouddrive\.cloudconsole\acc_<user>.img
# For Pwsh profile, see https://docs.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-core-60?view=powershell-6#filesystem

$script:UserDefaultPath = $HOME
$script:CurrentHostProfilePath = (Microsoft.PowerShell.Management\Join-Path -Path $script:UserDefaultPath -ChildPath '.config/powershell/Microsoft.PowerShell_profile.ps1')
$script:AllHostsProfilePath    = (Microsoft.PowerShell.Management\Join-Path -Path $script:UserDefaultPath -ChildPath '.config/powershell/profile.ps1')

Complete-UpperCaseProfileFolderMigration


# To ensure that the installed script is immediately usable, we need to add the scope path to the PATH enviroment variable.
$scriptPath = Microsoft.PowerShell.Management\Join-Path $env:HOME '.local/share/powershell/Scripts'
$existingPath = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Process)
if(($existingPath -split ':') -notcontains $scriptPath)
{
    [System.Environment]::SetEnvironmentVariable('PATH', $existingPath + ':' + $scriptPath, [System.EnvironmentVariableTarget]::Process)
}

#endregion

#region Utility Functions

# Migrate profile from incorrect uppercase profile location to standard location. Added to help migration from a breaking change of fixing incorrectly cased powershell profile paths
function Complete-UpperCaseProfileFolderMigration {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
    param()

    $errorActionPreference = 'stop'

    $legacyUpperCaseProfilePath = (Microsoft.PowerShell.Management\Join-Path -Path $script:UserDefaultPath -ChildPath '.config/PowerShell')
    $standardProfilePath = Split-Path $script:CurrentHostProfilePath

    if (-not (Test-Path $legacyUpperCaseProfilePath)) {
        #Nothing to do
        return
    }

    $legacyUpperCaseProfilePathItem = Get-Item $legacyUpperCaseProfilePath
    if ($legacyUpperCaseProfilePathItem -isnot [IO.DirectoryInfo]) {
        #This would be a very rare occurance
        Write-Warning "A non-directory item was detected at $legacyUpperCaseProfilePathItem. You should remove this or otherwise transition it to $standardProfilePath"
        return
    }
    if ($legacyUpperCaseProfilePathItem.LinkType -eq 'SymbolicLink') {
        if ((Resolve-Path $legacyUpperCaseProfilePathItem.Target -ne $standardProfilePath)) {
            Write-Warning "A symbolic link was detected for the legacy profile folder $legacyUpperCaseProfilePathItem, but it points to $($legacyUpperCaseProfilePathItem.Target). You should remove this or otherwise transition it to $standardProfilePath"
            return
        } else {
            #A migration has already completed
            return
        }
    }

    if (Test-Path $standardProfilePath) {
        Write-Warning "$legacyUpperCaseProfilePathItem requires migration but a standard profile folder was already detected at $standardProfilePath. If you have completed migration manually, please remove $legacyUpperCaseProfilePathItem and any references to it."
        return
    }

    #Prerequisites for migration have been met at this point.
    Write-Warning "We have detected a legacy profile folder at $legacyUpperCaseProfilePathItem. We are moving this to the standard profile folder $standardProfilePath for you and will link the old location to maintain compatibility."

    if ($PSCmdlet.ShouldProcess("Migrate profile folder from $legacyUpperCaseProfilePathItem to $standardProfilePath")) {
        Move-Item -Path $legacyUpperCaseProfilePathItem -Destination $standardProfilePath
    }
    if ($PSCmdlet.ShouldProcess("Create symbolic link from $legacyUpperCaseProfilePathItem to $standardProfilePath to maintain compatibility")) {
        New-Item -ItemType SymbolicLink -Path $legacyUpperCaseProfilePath -Value $standardProfilePath
    }
}


# Helper to do telemetry logging.
function Invoke-CloudShellTelemetry
{
    param (
        [Parameter(Mandatory=$true)]
        [string] $LogLabel,
        [Parameter(Mandatory=$true)]
        [System.DateTime] $StartTime
    )

    $elapsed = [System.Math]::Round(([System.DateTime]::Now - $StartTime).TotalMilliseconds)

    # Calling a scoped module private function. Format: & ($moduleinfo){}
    & ($script:PSCloudShellUtilityModuleInfo){param([string]$Label, [double]$Elapsed)Add-CloudShellTelemetry -Name "ACC.POWERSHELL.$Label" -Value $Elapsed} -Label $LogLabel -Elapsed $elapsed
}

# Extract default subscriptionId from Storage Profile environment variable
# Format of Storage Profile- {"storageAccountResourceId":"/subscriptions/<subscriptionGuid>/resourcegroups/<resourceGroup>/providers/Microsoft.Storage/storageAccounts/<storageAccountId>","fileShareName":"<Blob File Share>","diskSizeInGB":<diskSize>}
function Get-SubscriptionIdFromStorageProfile
{
    $subscriptionId = ''
    $startTime = [System.DateTime]::Now

    try
    {
        if ($env:ACC_STORAGE_PROFILE)
        {
            $storageProfile = $env:ACC_STORAGE_PROFILE | Microsoft.PowerShell.Utility\ConvertFrom-Json
            $storageAccountResourceId = $storageProfile.storageAccountResourceId
            if ($storageAccountResourceId)
            {
                # storageAccountResourceId is organized by the delimiter '/'
                $storageAccountResourceIdTokens = $storageAccountResourceId.Split('/')
                if ($storageAccountResourceIdTokens.Count)
                {
                    # SubscriptionId is the next token after the keyword 'subscriptions'
                    # This way of picking ensures that any change in the subscriptionId token location is future proofed
                    $subscriptionId = $storageAccountResourceIdTokens[$storageAccountResourceIdTokens.IndexOf('subscriptions') + 1]
                }
            }
        }
    }
    finally
    {
        Invoke-CloudShellTelemetry -LogLabel "GETSUBSCRIPTIONID" -StartTime $startTime
    }

    $subscriptionId
}

# Authenticate to Azure Resource Manager Service using Identity (MSI) based auth
# This is a one time authentication at Shell startup
# The Identity endpoint $env:MSI_ENDPOINT takes care of keeping the auth current
function Connect-AzService
{
    param (

        [string]$currentSubscriptionId
    )

    # Enable Az Data collection
    # Else User is prompted when Connect-AzAccount is invoked
    Set-PSCloudShellTelemetry

    $startTime = [System.DateTime]::Now

    try
    {
        Microsoft.PowerShell.Core\Import-Module Az.Accounts
        # Removed AccountId as it's not required. When it is provided, it indicates using a user-assigned, rather than a system-assigned identity.
        # In the case where the user provides an account id, there are three possibilities: (1) It represents a clientId;
        # (2) It represents and ObjectId; (3) It represents the resource-id of a user-assigned identity.
        # Since (1) and (2) are both guids, when AccountId is a guid, we attempt authentication both using the 'client_id' query string
        # value in our request, and, if that fails, the 'object_id' query string value. So, if the msi service is set up to authenticate
        # using a particular user-assigned identity, and the user passes the appropriate object id or client id setting as AccountId,
        # the authentication will be successful.

        $envName = $env:ACC_CLOUD
        if ($CloudEnvironmentMap.ContainsKey($env:ACC_CLOUD))
        {
            $envName = $script:CloudEnvironmentMap[$env:ACC_CLOUD]
        }

        $addAzAccountParameters = @{'Identity' = $true; 'TenantId' = $env:ACC_TID; 'EnvironmentName' = $envName}
        if($currentSubscriptionId)
        {
            $addAzAccountParameters.Add('SubscriptionId', $currentSubscriptionId)
        }

        $azAccount = Az.Accounts\Connect-AzAccount @addAzAccountParameters -ErrorAction SilentlyContinue -ErrorVariable azError

        # Log any errors from Azure authentication
        if ($azError)
        {
            $errorFolderPath =  $script:UserDefaultPath
            $azureFolderPath = (Microsoft.PowerShell.Management\Join-Path  -Path $script:UserDefaultPath -ChildPath '.azure')
            if (Microsoft.PowerShell.Management\Test-Path -Path $azureFolderPath)
            {
                $errorFolderPath = $azureFolderPath
            }
            # Use  $script:UserDefaultPath Path if .azure folder does not exist
            $azErrorPath = Microsoft.PowerShell.Management\Join-Path -Path $errorFolderPath -ChildPath 'azError.err'
            $addAzAccountParameters.Keys > $azErrorPath
            $addAzAccountParameters.Values >> $azErrorPath
            $azError >> $azErrorPath
        }
    }
    finally
    {
        Invoke-CloudShellTelemetry -LogLabel "CONNECTAZURERMSERVICE" -StartTime $startTime
    }

    return $azAccount
}

# Authenticate to Azure Active Directory Service
# This function needs to be run once per shell startup and everytime we get a new token from the RP
# This deliberately shadows the Connect-AzureAD cmdlet because most of the time you want our version, and their error messages tell you to run this
function Connect-AzureAD
{
    $startTime = [System.DateTime]::Now

    try
    {
        $envName = $env:ACC_CLOUD
        if ($CloudEnvironmentMap.ContainsKey($env:ACC_CLOUD))
        {
            $envName = $script:CloudEnvironmentMap[$env:ACC_CLOUD]
        }

        # Remove AccountId from parameters since it's missing for some users; Plus, it doesn't affect the authorization.
        $azureADParameters = @{'Identity' = $true; 'TenantId' = $env:ACC_TID;  'AzureEnvironmentName' = $envName}

        # This call sets the local process context with the token, account and tenant information
        & $script:AzureADModuleName\Connect-AzureAD @azureADParameters -ErrorAction SilentlyContinue -ErrorVariable azureADError | Microsoft.PowerShell.Core\Out-Null

        # Log any errors from AzureAD authentication
        if ($azureADError)
        {
            $errorFolderPath = $script:UserDefaultPath
            $azureFolderPath = (Microsoft.PowerShell.Management\Join-Path -Path $script:UserDefaultPath -ChildPath '.azure')
            Microsoft.PowerShell.Utility\Write-Warning -Message "An error occurred while authenticating to $($script:AzureADModuleName). Check $azureFolderPath for logs"
            if (Microsoft.PowerShell.Management\Test-Path -Path $azureFolderPath)
            {
                $errorFolderPath = $azureFolderPath
            }
            # Use  $script:UserDefaultPath Path if .azure folder does not exist
            $azureADError > (Microsoft.PowerShell.Management\Join-Path -Path $errorFolderPath -ChildPath 'azureADError.err')
        }
    }
    finally
    {
        Invoke-CloudShellTelemetry -LogLabel "CONNECTAZUREADSERVICE" -StartTime $startTime
    }
}

function Set-PSCloudShellTelemetry
{
    $startTime = [System.DateTime]::Now

    try
    {
        # Default value in case PSCloudShellUtility is not loaded
        Microsoft.PowerShell.Core\Import-Module -Name Az.Accounts
        $productVersion = '0.1.0'
        $productName = 'ps-cloud-shell'

        [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent($productName, $productVersion)
        Az.Accounts\Enable-AzDataCollection -WarningAction SilentlyContinue
    }
    finally
    {
        Invoke-CloudShellTelemetry -LogLabel "ENABLECLOUDSHELLTELEMETRY" -StartTime $startTime
    }
}

function Invoke-PSCloudShellUserProfile
{
    $start = [System.DateTime]::Now

    # First run all hosts profile
    if(Microsoft.PowerShell.Management\Test-Path -Path $script:AllHostsProfilePath)
    {
        try
        {
            Microsoft.PowerShell.Utility\Write-Verbose -Message 'Loading AllHosts profile ...' -Verbose

            # As the startupscript.ps1 gets executed with "." for global scope, we use "." here to use the startupscript's scope, i.e., global.
            . $script:AllHostsProfilePath
        }
        catch
        {
            # Log a warning and continue if encountering any terminating errors from the running user profile
            Microsoft.PowerShell.Utility\Write-Warning -Message "$_"
        }
    }

    # Second run current host profile
    if(Microsoft.PowerShell.Management\Test-Path -Path $script:CurrentHostProfilePath)
    {
        try
        {
            Microsoft.PowerShell.Utility\Write-Verbose -Message 'Loading CurrentHost profile ...' -Verbose

            # As the startupscript.ps1 gets executed with "." for global scope, we use "." here to use the startupscript's scope, i.e., global.
            . $script:CurrentHostProfilePath
        }
        catch
        {
            # Log a warning and continue if encountering any terminating errors from the running user profile
            Microsoft.PowerShell.Utility\Write-Warning -Message "$_"
        }
    }

    Invoke-CloudShellTelemetry -LogLabel "USERPROFILELOAD" -StartTime $start

    # display time if it's greater than 1 second
    if($elapsed -gt '1000')
    {
        Microsoft.PowerShell.Utility\Write-Verbose -Message "Loading user profile took $elapsed ms." -Verbose
    }
}

# Define a custom prompt function for Azure drive (Azure:) only
# Since it is defined before user profile(s) are loaded, users can still customize prompt via profile
function prompt
{
     # If inside Azure PSDrive, show the current path above the prompt
     if(($pwd.Drive).Name -eq 'Azure' -and ($pwd.Provider).Name -eq 'SHiPS')
     {
         # There is a double prompt issue on pwsh bash using write-host here. See https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences for more details.
         # Gray #969696 is chosen because it's passed color contrast check for both bash and PowerShell blue
         # PS blue: #012456 vs #969696     5.11:1
         # Bash:    #000000 vs #969696     7.09:1
         $CSI=[char]0x1b + '['
         "${CSI}38;2;150;150;150m$($pwd)${CSI}00m`nPS Azure:\> "
     }
    # else use the default prompt
    else
    {
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
    }

    # .Link
    # https://go.microsoft.com/fwlink/?LinkID=225750
    # .ExternalHelp System.Management.Automation.dll-help.xml
}
#endregion

if (! $env:ACC_CLOUD) {
    # we are running locally, not in azure - skip setup steps
    return
}

#region Initialization

# show MOTD
& ($script:PSCloudShellUtilityModuleInfo){Get-CloudShellTip -ErrorAction SilentlyContinue}

# Set the user profile path to clouddrive
Microsoft.PowerShell.Utility\Set-Variable -Name PROFILE -Value $script:CurrentHostProfilePath -Scope Global
$PROFILE = $PROFILE | Microsoft.PowerShell.Utility\Add-Member -MemberType NoteProperty -Name CurrentUserAllHosts -Value $script:AllHostsProfilePath -PassThru
$PROFILE = $PROFILE | Microsoft.PowerShell.Utility\Add-Member -MemberType NoteProperty -Name CurrentUserCurrentHost -Value $script:CurrentHostProfilePath -PassThru

# Dogfood initialization script
if ($env:ACC_CLOUD -eq 'dogfood')
{
    Microsoft.PowerShell.Utility\Write-Warning -Message "You are running in a dogfood environment. Please supply a URI for Azure dogfood environment initialization script."
    $dfEnvInitScriptURI = Microsoft.PowerShell.Utility\Read-Host -Prompt "Supply the URI"
    $dfEnvInitScript = Microsoft.PowerShell.Utility\Invoke-WebRequest -Uri $dfEnvInitScriptURI -UseBasicParsing | ForEach-Object Content
    $null = [ScriptBlock]::Create($dfEnvInitScript).Invoke()
}

if($script:SkipMSIAuth -eq $true)
{
    Microsoft.PowerShell.Utility\Write-Debug -Message "Skip authenticating with MSI, instead test scripts will take care of Auth."
}
else
{
    Microsoft.PowerShell.Utility\Write-Debug -Message "Authenticating with MSI ..."

    $AuthStartTime = [System.DateTime]::Now
    try
    {
        # Authenticate to Azure services
        # Use the default subscriptionId from Storage Profile to optimize authenticating to Azure Services using Connect-AzAccount
        Microsoft.PowerShell.Utility\Write-Verbose -Verbose -Message 'Authenticating to Azure ...'

        if (-not (Connect-AzService -currentSubscriptionId (Get-SubscriptionIdFromStorageProfile)))
        {
            Microsoft.PowerShell.Utility\Write-Warning -Message 'Azure Authentication failed.'
            . Invoke-PSCloudShellUserProfile
            return
        }
    }
    finally
    {
        # Measure the time spent on the Azure authentication
        Invoke-CloudShellTelemetry -LogLabel "AZUREAUTHENTICATION" -StartTime $AuthStartTime
    }
}

#endregion

#region AzureAD

# Import AzureAD module so cmdlets are visible, they are not currently being auto-discovered
$azureADLoadStartTime = [System.DateTime]::Now
try
{
    Microsoft.PowerShell.Core\Import-Module -Name $script:AzureADModuleName
}
finally
{
    Invoke-CloudShellTelemetry -LogLabel "AZUREADLOAD" -StartTime $azureADLoadStartTime
}

#endregion

#region User Specific

. Invoke-PSCloudShellUserProfile

# Set PSDefaultParameterValues for cmdlets
$PSDefaultParameterValues = @{'Install-Module:Scope' = 'CurrentUser'; 'Install-Script:Scope' = 'CurrentUser'}

#region Initialize AzurePSDrive

$startLoadingModules = [System.DateTime]::Now
try
{
    Microsoft.PowerShell.Core\Import-Module -Name AzurePSDrive
    Microsoft.PowerShell.Utility\Write-Verbose -Verbose -Message 'Building your Azure drive ...'
}
finally
{
    Invoke-CloudShellTelemetry -LogLabel "LOADCLOUDSHELLMODULES" -StartTime $startLoadingModules
}

$startBuildingShips = [System.DateTime]::Now
try
{
    $null = Microsoft.PowerShell.Management\New-PSDrive -Name Azure -PSProvider SHiPS -Root "AzurePSDrive#Azure" -Scope Global
    if(-not $?)
    {
        Microsoft.PowerShell.Utility\Write-Warning -Message 'Something went wrong while creating Azure drive. You can still use this shell to run Azure PowerShell commands.'
    }
}
finally
{
    Invoke-CloudShellTelemetry -LogLabel "BUILDSHIPS" -StartTime $startBuildingShips
}

# Set the PSReadline key handler for CloudShell key bindings and telemetry.
# Note: Set-CloudShellPSReadLineKeyHandler has to be after loading user profiles
& ($script:PSCloudShellUtilityModuleInfo){Set-CloudShellPSReadLineKeyHandler}

Invoke-CloudShellTelemetry -LogLabel "STARTUPTIME" -StartTime $Startuptime

#endregion

#region Clean up temp Variables

# Clean up variables since this startup script runs at global scope
Microsoft.PowerShell.Utility\Remove-Variable -Name AllHostsProfilePath, CurrentHostProfilePath, Startuptime, elapsed, UserDefaultPath, startBuildingShips, startLoadingModules, AuthStartTime -ErrorAction Ignore
Microsoft.PowerShell.Management\Remove-Item -Path env:ACC_CLUSTER -ErrorAction Ignore

#endregion
