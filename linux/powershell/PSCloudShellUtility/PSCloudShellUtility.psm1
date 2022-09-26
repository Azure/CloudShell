#region Variables
Microsoft.PowerShell.Core\Set-StrictMode -Version Latest
Microsoft.PowerShell.Utility\Import-LocalizedData  LocalizedData -filename PSCloudShellUtility.Resource.psd1

$script:IsWindowsOS = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows

Enum OsType { Windows = 1; Linux = 2 }

$script:acronymLookup = $null
$script:CurrentConsoleHostHistorycount = $null
$script:HistoryIndex = 1
# keep the historycount up to 500 at the time of launching cloudshell.
# PSReadline hardcoded MaximumHistoryCount = 4096, otherwise we could use $MaximumHistoryCount directly
$script:MaximumHistoryCount = 500

$script:IsCore =  $PSVersionTable.PSEdition -eq 'Core'

# PowerShell Session Option when connecting to Windows targets
# This is required since we connect to a WinRM_HTTPS endpoint configured using a self-signed certificate
$script:sessionOption = [System.Management.Automation.Remoting.PSSessionOption]::new()
$script:sessionOption.SkipCACheck = $true
$script:sessionOption.SkipCNCheck = $true

#region Telemetry
$script:AppInsightTrackMetric = New-Object Microsoft.ApplicationInsights.TelemetryClient
# Use the same instrumentationKey from bash
$script:AppInsightTrackMetric.InstrumentationKey = '2d98668f-09f0-48a2-9df0-ba68f2ec3466'
# track commands
$script:AppInsightsTrackEvent = New-Object Microsoft.ApplicationInsights.TelemetryClient
$script:AppInsightsTrackEvent.InstrumentationKey = 'f48a52b4-cb01-4f54-8733-9bebfdeee1dd'

# properties can be used for data querying later on
$script:CommonMetricProperties = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.String]"
$script:CommonMetricProperties.Add('ACC_VERSION', $env:ACC_VERSION)
$script:CommonMetricProperties.Add('ACC_CLUSTER', $env:ACC_CLUSTER)
$script:CommonMetricProperties.Add('PSVersion', $PSVersionTable.PSVersion)
$script:CommonMetricProperties.Add('SessionId', (New-Guid))

# modules, tools and aliases are installed by default in the CloudShell
$script:DefaultInstalledModules=@('Pester', 'PackageManagement', 'PowerShellGet', 'PSReadline', 'PSCloudShellUtility')
$script:Tools=@('vim', 'git', 'pwsh', 'nano', 'code', 'emacs', 'az', 'ssh', 'sqlcmd', 'vi')
$script:BuiltinModuleNames=@('Microsoft.PowerShell.Core',
'Microsoft.PowerShell.Management',
'Microsoft.PowerShell.Archive',
'Microsoft.PowerShell.Host',
'Microsoft.PowerShell.Utility',
'Microsoft.PowerShell.Management',
'Microsoft.PowerShell.Security',
'Microsoft.PowerShell.Diagnostics',
'PSDesiredStateConfiguration',
'Microsoft.WSMan.Management',
'CimCmdlets',
'PSDiagnostics')
$script:BuiltinAliases=@(
'ac','asnp',
'cat', 'cd', 'CFS', 'chdir', 'clc', 'clear', 'clhy', 'cli', 'clp', 'cls', 'clv', 'cnsn', 'compare', 'copy', 'cp', 'cpi','cpp','curl','cvpa',
'dbp', 'del', 'diff', 'dir', 'dnsn',
'ebp', 'echo', 'epal', 'epcsv', 'epsn', 'erase', 'etsn', 'exsn',
'fc', 'fhx', 'fl', 'foreach', 'ft', 'fw',
'gal', 'gbp', 'gc', 'gcb', 'gci', 'gcm', 'gcs', 'gdr', 'ghy', 'gi', 'gin', 'gjb', 'gl', 'gm', 'gmo',' gp', 'gps', 'gpv', 'group', 'gsn','gsnp','gsv', 'gtz', 'gu',  'gv',  'gwmi',
'h',  'history',
'icm','iex',  'ihy', 'ii', 'ipal', 'ipcsv', 'ipmo','ipsn','irm', 'ise','iwmi', 'iwr',
'kill',
'lp', 'ls',
'man', 'md',  'measure', 'mi', 'mount', 'move','mp', 'mv',
'nal','ndr', 'ni', 'nmo','npssc', 'nsn',  'nv',
'ogv', 'oh',
'popd', 'ps', 'pushd', 'pwd',
'r', 'rbp', 'rcjb', 'rcsn',  'rd',  'rdr', 'refreshenv', 'ren','ri',  'rjb',  'rm', 'rmdir',  'rmo', 'rni','rnp', 'rp', 'rsn', 'rsnp', 'rujb','rv',  'rvpa', 'rwmi',
'sajb', 'sal',  'saps',  'sasv', 'sbp',  'sc', 'scb',  'select',  'set', 'shcm', 'si', 'sl', 'sleep','sls', 'sort', 'sp', 'spjb', 'spps','spsv', 'start', 'stz', 'sujb', 'sv', 'swmi',
'tee', 'trcm',  'type',
'wget', 'where', 'wjb', 'write',
'%', '?'
)

#endregion

#region CloudShell commands

function Add-CloudShellTelemetry
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [double]$Value
    )

    # Calling TrackMetric API to log the metric to AppInsights service.
    $script:AppInsightTrackMetric.TrackMetric($Name, $Value, $script:CommonMetricProperties)
}

function Set-CloudShellPSReadLineKeyHandler
{
    # PSReadline module may be unloaded or gets deleted from user profiles
    if(-not (Microsoft.PowerShell.Core\Get-Module -Name PSReadline))
    {
        return
    }

    # PSReadline follows Emacs keybindings (https://en.wikipedia.org/wiki/GNU_Readline), `Alt+F` and `Alt+B` are used for
    # moving backward and forward word by word. However MacBook enables Ctrl+ArrowLeft` and `Ctrl+ArrowRight` by default and cloudshell
    # Bash supports them too. Therefore we add these keyhandlers in PowerShell cloudshell.
    PSReadline\Set-PSReadLineKeyHandler -Chord  CTRL+LeftArrow BackwardWord
    PSReadline\Set-PSReadLineKeyHandler -Chord  CTRL+RightArrow ForwardWord
    # The darkgray color currently in use is not readable for Parameters and Operators so change them to light gray.
    PSReadline\Set-PSReadLineOption -Colors @{
        'Parameter'="$([char]0x1b)[38;2;150;150;150m"
        'Operator'="$([char]0x1b)[38;2;150;150;150m"
    }

    # Fix Bug 2271907 - OS and Browser coverage: cut&paste to PowerShell Cloudshell reverse ordered on Mac/Chrome, firefox
    # Root Cause: Firefox/Linux/Mac uses LF(LineFeed) for newline; while other cases use CRLF(Carriage Return & Line Feed).
    # LF is interpreted as Ctrl+Enter and triggers InsertLineAbove which pushes each text line down as the paste is getting processed one char at a time,
    # CRLF works fine because CR triggers AcceptLine.
    # To fix it, need to remove the keybinding for Ctrl+Enter of InsertLineAbove.
    # This keyBound doesn't exist DefaultEmacsBindings, only in DefaultWindowsBindings. This explains why bash works fine.
    PSReadline\Remove-PSReadlineKeyHandler -Key Ctrl+Enter

    # Set historyhandler for telemetry
    if(-not (PSReadline\Get-PSReadlineOption).AddToHistoryHandler)
    {
        # Control the size of ConsoleHost_history.txt to workaround the limit its size issue  https://github.com/lzybkr/PSReadLine/issues/537
        try {
            # turn off history
            PSReadline\Set-PSReadlineOption -HistorySaveStyle SaveNothing
            $historyPath = (PSReadline\Get-PSReadlineOption).HistorySavePath
            if(Microsoft.PowerShell.Management\Test-Path -Path $historyPath)
            {
                $historyContent = Microsoft.PowerShell.Management\Get-Content -Path $historyPath
                # 'Count' property does not exist if the PSReadline HistorySavePath contains 1 record only
                $script:CurrentConsoleHostHistorycount = if($historyContent.GetType().Name -eq 'String'){1} else{$historyContent.Count}
                if($script:CurrentConsoleHostHistorycount -gt $script:MaximumHistoryCount)
                {
                    $tempContent = Microsoft.PowerShell.Management\Get-Content -Path $historyPath -Tail $script:MaximumHistoryCount -ReadCount $script:MaximumHistoryCount
                    Microsoft.PowerShell.Management\Set-Content -Path $historyPath -Value $tempContent -Force
                    $script:CurrentConsoleHostHistorycount = $script:MaximumHistoryCount
                }
            }
        }
        catch {
            Write-Warning "$_"
            return
        }
        finally {
            # reset back to default
            PSReadline\Set-PSReadlineOption -HistorySaveStyle SaveIncrementally
        }

        PSReadline\Set-PSReadlineOption -AddToHistoryHandler $PSReadlineHistoryHandler
    }
}

# Set a callback to PSReadline
$PSReadlineHistoryHandler={

    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Line
    )
    try
    {
        # Skip commands from ConsoleHost_history.txt
        if ($script:HistoryIndex -le $script:CurrentConsoleHostHistorycount)
        {
            $script:HistoryIndex++
            return $true
        }

        try {
            $cmdline=[ScriptBlock]::Create($Line)
        }
        catch{
            # ignore commands PowerShell cannot interpret such as $env:, $home/helloworld.ps1
            return $true
        }
        $commandInfo=$cmdline.Ast.FindAll({$args[0] -is [System.Management.Automation.Language.CommandAst]}, $true)

        if(-not $commandInfo)
        {
            # returning true means the command goes to the history that's the default behavior.
            return $true
        }

        $commandName=$commandInfo.GetCommandName()
        if(-not $commandName)
        {
            return $true
        }

        if($commandInfo.Count -gt 1)
        {
            # $commandName can be Object[]
            $commandName.foreach{
                if(-not [System.String]::IsNullOrWhiteSpace($_))
                {
                    # call the function if the command is not empty or whitespaces
                    Add-CloudShellCustomEvent -CommandName $_
                }
            }
        }
        else
        {
            Add-CloudShellCustomEvent -CommandName $commandName
        }
    }
    catch
    {
        Write-Warning "`n$_"
    }

    return $true
}

function Add-CloudShellCustomEvent
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$CommandName
    )

    $command = Microsoft.PowerShell.Core\Get-Command -Name $commandName -ErrorAction Ignore
    if(-not $command)
    {
        # does nothing for null command
        return $true
    }

    # Builtin aliases and tools
    if(($script:BuiltinAliases -contains $command.Name) -or ($script:Tools -contains $command.Name))
    {
        $script:AppInsightsTrackEvent.TrackEvent($command.Name, $script:CommonMetricProperties, $null)
        return $true
    }

    # Workaround a PowerShell issue: Run 'Get-Command ?' returns an array object, expected a single command object
    if($CommandName -eq '?')
    {
        $script:AppInsightsTrackEvent.TrackEvent($CommandName, $script:CommonMetricProperties, $null)
        return $true
    }

    $eventName = $null

    # Check $command.Source for some builtin cmdlets such as Get-Module that returns null from (get-command get-module).Module
    # On linux, the builtin commands are listed in BuiltinModuleNames
    if($command.Source -and ($script:BuiltinModuleNames -contains $command.Source))
    {
        # Use $command.Name instead of $commandName because it's normalized for case sensitivity
        $eventName = Microsoft.PowerShell.Management\Join-Path $command.Source $command.Name
    }
    # Handling PowerShell modules
    elseif($command.Module)
    {
        # Builtin modules from programfiles
        if($script:DefaultInstalledModules -contains $command.ModuleName)
        {
            $eventName = Microsoft.PowerShell.Management\Join-Path $command.ModuleName $command.Name
        }
        else
        {
            # Handling inbox modules or those from PowerShellGallery
            $modulePath=$command.Module.ModuleBase
            if($modulePath)
            {
                if (($modulePath -like '/usr/local/share/powershell/Modules/*') -or ($modulePath -like '/opt/microsoft/powershell/*'))
                {
                    $eventName = Microsoft.PowerShell.Management\Join-Path $command.ModuleName $command.Name
                }
                else
                {
                    $psgetModuleInfoFile=Microsoft.PowerShell.Management\Join-Path -Path $modulePath -ChildPath PSGetModuleInfo.xml
                    if(Microsoft.PowerShell.Management\Test-Path $psgetModuleInfoFile)
                    {
                        $content = Microsoft.PowerShell.Management\Get-Content $psgetModuleInfoFile
                        if(($content -match '<S.*RepositorySourceLocation.*powershellgallery.com.*/S>') -or ($content -match '<S.*RepositorySourceLocation.*www.poshtestgallery.com.*/S>'))
                        {
                            $eventName = Microsoft.PowerShell.Management\Join-Path $command.ModuleName $command.Name
                        }
                    }
                }
            }
        }
    }
    #Handling scripts
    elseif($command.Source -and $command.Name)
    {
        $psScript=[System.IO.Path]::GetFileNameWithoutExtension($command.Name)
        $psgetScriptInfoFile=[System.IO.Path]::Combine((Microsoft.PowerShell.Management\Split-Path $command.Source -Parent), 'InstalledScriptInfos', "$($psScript)_InstalledScriptInfo.xml")

        if(Microsoft.PowerShell.Management\Test-Path $psgetScriptInfoFile)
        {
            $content = Microsoft.PowerShell.Management\Get-Content $psgetScriptInfoFile
            if(($content -match '<S.*RepositorySourceLocation.*powershellgallery.com.*/S>') -or ($content -match '<S.*RepositorySourceLocation.*dtlgalleryint.cloudapp.net.*/S>'))
            {
                $eventName = $command.Name
            }
        }
    }

    if($eventName)
    {
        #Syntax: TrackEvent(name, properties, metrics)
        $script:AppInsightsTrackEvent.TrackEvent($eventName, $script:CommonMetricProperties, $null)
        return $true
    }
}

$script:cloudshellTempDir = $null
$script:tempPath = [System.IO.Path]::GetTempPath();
function Export-File
{
    <#
    .SYNOPSIS
       Exports files and directories from your cloudshell to your local machine.
    .PARAMETER Path
       Specifies, as a string array, the path to the items to be exported. Supports multiple items.
    .PARAMETER LiteralPath
       Specifies, as a string array, the path to the items to be exported. Unlike Path, the value of the LiteralPath is used exactly as it is typed. Supports multiple items.
    .PARAMETER InputObject
       Specifies the object to be exported. Enter a variable that contains the objects, or type a command or expression that gets the objects. You can also pipe objects to Export-File.
    .EXAMPLE
        Export-File -path ~/hello.ps1
        Export-File -path ~/hello*.ps1
        Export-File -path ~/h1.ps1, ~/h2.ps1
        Export-File -path ~/hellofolder
        dir *.txt | Export-File -Verbose
        "Hello World!" | Export-File
    #>

    [CmdletBinding(DefaultParameterSetName='ByPath', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByPath')]
        [string[]]$Path,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByLiteralPath')]
        [string[]]$LiteralPath,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ByObject')]
        [object]$InputObject
    )

    Begin
    {
        if ($($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows)
        {
            $message = $LocalizedData.OSNotSupported -f ('Export-File', 'Windows', 'Linux')
            ThrowError -ExceptionName "System.NotSupportedException" `
            -ExceptionMessage $message `
            -ErrorId "OSNotSupported" `
            -CallerPSCmdlet $PSCmdlet `
            -ErrorCategory InvalidOperation `
            -ExceptionObject $PSCmdlet
        }

        $objects=@()
        $isLiteralPath = $false
    }

    Process
    {
        if ($PSCmdlet.ParameterSetName -eq 'ByObject')
        {
            if ($InputObject -is [System.IO.FileSystemInfo])
            {
                # Handling cases like dir *.txt | Export-File; Get-Item hello.ps1 | Export-File
                Copy-FromCloudShell -Item $InputObject
            }
            else
            {
                if ($InputObject.PSObject.Properties['Path'])
                {
                    # Handling cases where Path is from pipeline.
                    # Note when both ValueFromPipeline and ValueFromPipelineByPropertyName exist, ValueFromPipeline takes precedence.
                    # Thus we need to handle them explicitly here
                    $Path += $InputObject.Path
                }
                elseif ($InputObject.PSObject.Properties['LiteralPath'])
                {
                    # Handling cases where Path is from pipeline
                    $Path += $InputObject.LiteralPath
                    $isLiteralPath = $true
                }
                else
                {
                    # Handling cases like "hello world | Export-File
                    $objects += $InputObject
                }
            }
        }
    }
    End
    {
        if ($LiteralPath)
        {
            $isLiteralPath = $true
            $Path = $LiteralPath
        }

        if ($Path)
        {
            foreach ($each in $Path)
            {
                $items = if ($isLiteralPath ){Microsoft.PowerShell.Management\Get-Item -LiteralPath $each} else {Microsoft.PowerShell.Management\Get-Item -Path $each}

                # Note the $items can be a single item or a collection if $each contains wildcard.
                foreach ($item in $items)
                {
                    Copy-FromCloudShell -Item $item
                }
            }
        }
        elseif ($objects.Count -ne 0)
        {
            # Exporting content texts. The temp file name follows cloudshell-<randomname> format.
            Set-TempDirectory

            $newName = 'cloudshell-' + [System.IO.Path]::GetRandomFileName()
            $tmp = Microsoft.PowerShell.Management\Join-Path -Path $script:cloudshellTempDir -ChildPath $newName
            Microsoft.PowerShell.Management\Set-Content -Path $tmp -Value $objects -Force
            if (Microsoft.PowerShell.Management\Test-Path -Path $tmp)
            {
                Write-Verbose "Downloading $tmp" -Verbose
                download $tmp
            }
        }
    }
}

function Copy-FromCloudShell
{
    <#
    .SYNOPSIS
       An internal private help function that downloads files and directories from the cloudshell.
    #>

    param (
        [System.IO.FileSystemInfo] $Item
    )

    # Handle files under filesystem provider only
    if (-not (($Item.PSPath).StartsWith('Microsoft.PowerShell.Core\FileSystem')))
    {
        return
    }

    # Limitation: The download command supoprts $home or tmp directory only.
    if (-not ($Item.FullName.StartsWith($HOME) -or $Item.FullName.StartsWith($script:tempPath)))
    {
        $message = $LocalizedData.PathNotSupported -f ('Export-File', "$HOME or $script:tempPath")
        ThrowError -ExceptionName "System.NotSupportedException" `
        -ExceptionMessage $message `
        -ErrorId "PathNotSupported" `
        -CallerPSCmdlet $PSCmdlet `
        -ErrorCategory InvalidOperation `
        -ExceptionObject $PSCmdlet
        return
    }
    
    if ($item -is [System.IO.FileInfo])
    {
        # item is a file, go ahead to download. Note: No check is necessary because get-item has done that.
        $fullPath = $Item.FullName
        Write-Verbose "Downloading $fullPath" -Verbose
        download "$fullPath"
        # Workaround due to the bug in download command
        Microsoft.PowerShell.Utility\Start-Sleep -Seconds 1
    }
    elseif ($item -is [System.IO.DirectoryInfo])
    {
        # Exporting a directory. The directory will be zipped and filename is cloudshell-<foldername>.zip
        Set-TempDirectory
        $fullPath = $Item.FullName
        $filename = 'cloudshell-' + $Item.Name + '.zip'
        $tmp = Microsoft.PowerShell.Management\Join-Path -Path $script:cloudshellTempDir -ChildPath $filename
        write-verbose "running jar cMvf $tmp -C $fullPath ."

        # Zip the directory. Note using jar instead of zip is to ignore original top-level folder structure.
        $null = jar cMvf $tmp -C $fullPath .
        
        if ((Microsoft.PowerShell.Management\Test-Path -Path $tmp) -or (Microsoft.PowerShell.Management\Test-Path -LiteralPath $tmp))
        {
            Write-Verbose "Downloading $tmp" -Verbose
            download $tmp
        }
    }
    else {
        # If -path contains text that should be treated -LiteralPath, but a user does not specify -LiteralPath
        # Get-Item will return empty results. We'll end up here.
    }
}

function Set-TempDirectory
{
    <#
    .SYNOPSIS
       An internal private help function that sets up the directory for storing temporally files.
    #>

    if (-not $script:cloudshellTempDir)
    {
        # If the directory, $home\.tmp, does not exist, create it.
        # Note that the download command only works for files under home directory
        $script:cloudshellTempDir = Microsoft.PowerShell.Management\Join-Path -Path $Home -ChildPath '.tmp'
    }
    if (-not (Microsoft.PowerShell.Management\Test-Path -Path $script:cloudshellTempDir))
    {
        $null = Microsoft.PowerShell.Management\New-Item -Path $script:cloudshellTempDir -ItemType Directory -Verbose
    }
    else
    {
        # Clean up old files
        $items = Microsoft.PowerShell.Management\Get-ChildItem -Path $script:cloudshellTempDir
        foreach ($item in $items)
        {
            if(-not $item.Name.StartsWith('cloudshell-'))
            {
                continue
            }

            # Files are expected to be downloaded less than 120 minutes
            $duration = ([System.DateTime]::Now - $item.LastAccessTime).TotalMinutes
            if ($duration -ge 120)
            {
                Write-Verbose "Removing $item"
                Remove-Item $item -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
function Dismount-CloudDrive
{
    <#
    .SYNOPSIS
       Dismounts Azure File storage share from the current session.
    .PARAMETER Force
       When this switch is set, no prompt to user for the confirmation before unmounting the fileshare.
    .INPUTS
       None
       You cannot pipe input to this command.
    .OUTPUTS
       None.
    .EXAMPLE
       Dismount-CloudDrive
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter()]
        [switch] $Force
    )

    # We are not calling Get-CloudDrive before dismounting it because something like the following cases that changed in browsers
    # don't actually impact the user storageprofile information stored in backend (via RP). Thus we should allow to dismount even if
    # the user's curerent session is not in good state.
    #
    #  Cases:
    #  * In the cloudshell, a user deleted the clouddrive through net use /delete
    #  * manually modified the env:ACC_STORAGE_PROFILE
    #

    $driveInfo = $LocalizedData.DismountingClouddrive

    if ($PSCmdlet.ShouldProcess($driveInfo))
    {
        if ($Force -or $PSCmdlet.ShouldContinue($LocalizedData.DismountQueryMessage, $LocalizedData.DismountCaption))
        {
            # These HTTP requests are in sync with bash src/images/agent/linux/clouddrive
            try
            {
                Write-Verbose $LocalizedData.UpdatingUserSettings
                $null=Invoke-WebRequest -Uri 'http://127.0.0.1:8888/userSettings'  -Method 'DELETE'  -UseBasicParsing -ContentType 'application/json'

                Write-Verbose $LocalizedData.DismountingClouddrive
                $null=Invoke-WebRequest -Uri 'http://127.0.0.1:8888/cloudshell'  -Method 'DELETE'  -UseBasicParsing -ContentType 'application/json'
            }
            catch
            {

                $message = $LocalizedData.DismountCloudDriveFailed -f $_

                ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "DismountCloudDriveFailed" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation `
                        -ExceptionObject $PSCmdlet
            }
        }
    }
}

function Get-CloudDrive
{
    <#
    .SYNOPSIS
       List information of the Azure File storage share that is mounted as 'CloudDrive'.
    .PARAMETER
       None.
    .INPUTS
       None
       You cannot pipe input to this command.
    .OUTPUTS
       Returns the mounted file share information including subscription, resourcegroup and storageaccount.
     .EXAMPLE
        Get-CloudDrive
    #>

    [CmdletBinding()]
    param (
    )

    $clouddrivePath = Microsoft.PowerShell.Management\Join-Path -Path $HOME -ChildPath 'clouddrive'

    # Check if the clouddrive exists. This case will unlikely happen because there is a pop dialogbox during logon.
    # for Persist Account files https://docs.microsoft.com/en-us/azure/cloud-shell/overview. But we do check here anyway.
    if (-not (Test-Path $clouddrivePath)) {
        Write-Warning $LocalizedData.ClouddriveNotMounted
        return
    }

    # Check if the clouddrive folder exists. This case may occur when a user on purposely deleted the clouddrive through net use Y: /delete
    $null = Get-ChildItem $clouddrivePath -ErrorAction SilentlyContinue -ErrorVariable ev

    if($ev){
        Write-Warning $LocalizedData.ClouddriveNotMounted
        return
    }

    # If a user delete $env:ACC_STORAGE_PROFILE, this error case can happen
    $AccStorageProfile = Microsoft.PowerShell.Management\Get-Item -Path env:ACC_STORAGE_PROFILE -ErrorAction SilentlyContinue -ErrorVariable ev
    if(-not $AccStorageProfile -or $ev){

        $message = $LocalizedData.StorageProfileDoesnotExist -f $ev
        ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "StorageProfileDoesnotExist" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidData `
                        -ExceptionObject $PSCmdlet
    }

    # Check if the env is valid
    try
    {
        $json = Microsoft.PowerShell.Utility\ConvertFrom-Json $AccStorageProfile.Value
    }
    catch
    {
        $message = $LocalizedData.StorageProfileHasInvalidContent -f $_
        ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "StorageProfileHasInvalidContent" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidData `
                        -ExceptionObject $AccStorageProfile
    }

    # storageProfile contract:
    $storageProfileFormat="{`"storageAccountResourceId`":`"/subscriptions/<id>/resourceGroups/<rgname>/providers/Microsoft.Storage/storageAccounts/<saName>`", `"fileShareName`": `"<myshare>`", `"diskSizeInGB`":5}."

    try
    {
        $fileshare = $json.fileShareName
        $objArray  = $json.storageAccountResourceId -split "/"
    }
    catch
    {
        $message = $LocalizedData.StorageProfileHasUnsupportedJsonFormat -f ($storageProfileFormat, $_.Exception.Message)

        ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "StorageProfileHasUnsupportedJsonFormat" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidData `
                    -ExceptionObject $AccStorageProfile
    }

    # we expected subscription, resourcegroup and storageaccount are set in the storageAccountResourceId. Thus the length of $objArray is at least 6
    if(-not $objArray -or $objArray.Count -lt 6)
    {
        $message = $LocalizedData.StorageAccountResourceIdHasUnsupportedJsonFormat -f ($storageProfileFormat)

        ThrowError -ExceptionName "System.InvalidOperationException" `
            -ExceptionMessage $message `
            -ErrorId "StorageAccountResourceIdHasUnsupportedJsonFormat" `
            -CallerPSCmdlet $PSCmdlet `
            -ErrorCategory InvalidData `
            -ExceptionObject $AccStorageProfile
    }

    $subscription=$null
    $resourceGroup=$null
    $storageAccount=$null

    $stack = [system.collections.stack]::new()

    for($i=$objArray.Count - 1; $i -ge 0; $i--)
    {
        $stack.Push($objArray[$i]);
    }

    while ($stack.Count -gt 0)
    {
        $resourceInfo = $stack.Pop()
        switch($resourceInfo)
        {
            "subscriptions"     { $subscription = $stack.Pop(); break }
            "resourceGroups"    { $resourceGroup = $stack.Pop(); break }
            "storageAccounts"   { $storageAccount = $stack.Pop(); break }
        }
    }

    # Check if all these variables are set.
    if(-not ($subscription -and $resourceGroup -and $storageAccount -and $fileshare))
    {
        $message=$LocalizedData.MissingStorageProfileProperty -f ($subscription, $resourceGroup, $storageAccount, $fileshare)
        Write-Error -Message $message -Category InvalidData -ErrorId "MissingStorageProfileProperty"
    }


    $dirSeparatorChar = [System.IO.Path]::DirectorySeparatorChar
    $object= New-Object PSCustomObject -Property ([Ordered]@{
        "FileShareName" = "$fileshare"
        "FileSharePath" = $dirSeparatorChar + [System.IO.Path]::Combine($dirSeparatorChar, "$storageAccount.file.core.windows.net", $fileshare)
        "MountPoint" = "$clouddrivePath"
        "Name" = "$storageAccount"
        "ResourceGroupName" = "$resourceGroup"
        "StorageAccountName" = "$StorageAccount"
        "SubscriptionId" = "$subscription"
   })

   $object.pstypenames.Insert(0,'PSCloudShell.CloudDrive')
   return $object
}

function Get-CloudShellTip
{
    <#
    .SYNOPSIS
       List CloudShell PowerShell Tips.
    .PARAMETER All
       Switch parameter to show All tips. When not specified, show only one tip randomly.
    .EXAMPLE
        Get-CloudShellTip
        Show one tip randomly.
    .EXAMPLE
        Get-CloudShellTip -All
        Show all tips.
    #>

    [CmdletBinding()]
    param (
        [switch]$All
    )

    $tipFilePath = Microsoft.PowerShell.Management\Join-Path -Path $PSScriptRoot -ChildPath "tips.json"
    $message = $null

    $tipsJson = Get-Content $tipFilePath | Microsoft.PowerShell.Utility\ConvertFrom-Json

    if($All)
    {
        $message = $tipsJson.items
    } else {
        $randomTip = $tipsJson.items | Microsoft.PowerShell.Utility\Get-Random

        if(-not [string]::IsNullOrEmpty($randomTip))
        {
            $message = "MOTD: " + $randomTip        
            $message = "`r`n" + $message + "`r`n";
        }
    }

    return $message
}

#endregion

#region Az commands

function Get-AzVMPublicIPAddress
{
    <#
        .DESCRIPTION
        Returns the public IPAddress or DNS Name of the Azure VM

        .PARAMETER Name
        Name of the Azure VM

        .PARAMETER ResourceGroupName
        Name of the resource group the VM belongs to

        .EXAMPLE
        Get-AzVMPublicIPAddress -Name AzureVmName -ResourceGroupName ResourceGroupName
    #>

    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ResourceGroupName
    )

    $azVM = Az.Compute\Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction SilentlyContinue
    if(-not $azVM) {
        $message = $LocalizedData.GetAzureVMError -f ($Name)
        Write-Error -Message $message -ErrorId "AzureVMNameNotAvailable" -Category InvalidArgument
        return $azVM
    }

    $azVMNetInterfacesId = Split-Path -Leaf $azVM.NetworkProfile.NetworkInterfaces[0].Id
    $azVMInferface = Az.Network\Get-AzNetworkInterface -Name $azVMNetInterfacesId -ResourceGroupName $ResourceGroupName
    $azVMPublicIPId = Split-Path -Leaf $azVMInferface.IpConfigurations.PublicIpAddress.id
    $ipAddressObj = Az.Network\Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $azVMPublicIPId

    # Ip address can be 'not assigned',
    # e.g. when computer is shut down
    if($ipAddressObj.IpAddress -eq 'Not Assigned') {
        $message = $LocalizedData.GetAzureVMShutDown -f ($Name)
        Write-Error -Message $message -ErrorId "AzureVMShutDown" -Category ConnectionError
        return $null
    }

    $ComputerName = $ipAddressObj.IpAddress

    # If FQDN is not set, return the IP Address
    if($ipAddressObj.DnsSettings) {
        $fqdn = $ipAddressObj.DnsSettings.Fqdn
        if($fqdn) {$ComputerName = $fqdn}
    }

    $verboseMessage = $LocalizedData.GetAzureVMIPVerboseMsg -f ($Name, $ComputerName)
    Write-Verbose -Message $verboseMessage

    # Add this ComputerName to Trusted Host only on Windows OS
    # This ComputerName can be IP or FQDN
    Update-WinRMTrustedHosts -ComputerNameOrIPAddress $ComputerName

    $ComputerName
}

function Update-WinRMTrustedHosts {
    param(
        [Parameter(Mandatory=$true)]
        $ComputerNameOrIPAddress
    )

    # WSMan:\ is applicable only in Windows environment
    if (-not $script:IsWindowsOS)
    {
        return
    }

    $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts

    if($trustedHosts.Value.Split(",") -notcontains $ComputerNameOrIPAddress) {
        $verboseMsgAddComputer = $LocalizedData.VerboseMsgAddComputer -f ($ComputerNameOrIPAddress)
        Write-Verbose -Message $verboseMsgAddComputer

        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $ComputerNameOrIPAddress -Concatenate -Force
    }
}

function Invoke-AzVMCommand
{
    <#
        .DESCRIPTION
        Invokes the given command on the list of given Azure VMs

        .PARAMETER Name
        Specifies the computername

        .PARAMETER ResourceGroupName
        Provide the name of the resource group

        .PARAMETER ScriptBlock
        The ScriptBlock that needs to be executed

        .PARAMETER Credential
        Provide Credential when connecting to Windows Targets

        .PARAMETER UserName
        Provide UserName when connecting to Linux Targets. When used with KeyFilePath parameter, identifies the user on the remote computer

        .PARAMETER KeyFilePath
        Provide SSH KeyFile Path when connecting to Linux Targets, if connection uses Key based authentication       
                
        .EXAMPLE
        Invoke-AzVMCommand -Name WindowsVM -ResourceGroupName ResourceGroupName -ScriptBlock ScriptBlock -Credential credential

        .EXAMPLE
        Invoke-AzVMCommand -Name LinuxVM -ResourceGroupName ResourceGroupName -ScriptBlock ScriptBlock -UserName username

        .EXAMPLE
        Invoke-AzVMCommand -Name LinuxVM -ResourceGroupName ResourceGroupName -ScriptBlock ScriptBlock -UserName username -KeyFilePath ~/.ssh/id_rsa
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory, ParameterSetName='wsman')]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$Credential,

        [Parameter(Mandatory, ParameterSetName='ssh')]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(ParameterSetName='ssh')]
        [ValidateNotNullOrEmpty()]
        [string]$KeyFilePath
    )
    
        if(-not (Test-AzResourceGroup -ResourceGroupName $ResourceGroupName)) {
            $badResourceGroup = $LocalizedData.TestAzResourceGroup -f ($ResourceGroupName)
            throw [System.ArgumentException] $badResourceGroup
        }

        $OsType = Get-OsType -Name $Name -ResourceGroupName $ResourceGroupName
        if (-not $OsType)
        {
            $badTargetVM = $LocalizedData.BadTargetVM
            throw [System.ArgumentException] $badTargetVM
        }

        $testAzVMParams = @{'Name'=$Name;'ResourceGroupName'=$ResourceGroupName;'OsType'=$OsType}
        if ([OStype]::Windows -eq $OsType)
        {
            if (-not $Credential)
            {
                $message = $LocalizedData.CredentialError
                throw [System.ArgumentException] $message
            }            
        }

        $cName = Test-AzVM @testAzVMParams
        if(-not $cName) {
            $message = $LocalizedData.GetAzureVMError -f ($Name)
            throw [System.ArgumentException] $message
        }
    
        if ([OStype]::Windows -eq $OsType)
        {
            $invokeCommandParams = @{
                    ComputerName = $cName
                    UseSSL = $true
                    Credential = $Credential
                    SessionOption = $script:sessionOption
                    ScriptBlock = $ScriptBlock                    
                    Authentication = 'Basic'
            }            
        }
        elseif ([OStype]::Linux -eq $OsType)
        {
            $invokeCommandParams = @{'HostName'=$cName;'ScriptBlock'=$ScriptBlock}

            if ($KeyFilePath)
            {
                $invokeCommandParams.Add('KeyFilePath',$KeyFilePath)
            }

            if ($Credential -and $Credential.UserName)
            {
                $invokeCommandParams.Add('UserName',$Credential.UserName)
            }
            elseif ($UserName)
            {
                $invokeCommandParams.Add('UserName',$UserName)
            }
            else
            {
                $message = $LocalizedData.UserNameError
                throw [System.ArgumentException] $message
            }
        }

        Invoke-Command @invokeCommandParams -ErrorAction Stop    
}

function Get-AzVmNsg
{
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ResourceGroupName
    )

    $azVM = Az.Compute\Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Name

    if (-not $azVM)
    {
        $badTarget = $LocalizedData.GetAzureVMError -f ($Name)
        throw [System.ArgumentException] $badTarget
    }

    $nsg = @()

    $azVMNetInterfacesId = $azVM.NetworkProfile.NetworkInterfaces[0].Id
    $networkInterface = Split-Path $azVMNetInterfacesId -Leaf

    # Get Interface level NSG
    Az.Network\Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
        | Foreach-Object                                                                              `
            {                                                                                         `
                if ($_.NetworkInterfaces -and ($_.NetworkInterfaces.Id -eq $azVMNetInterfacesId))     `
                {                    
                    $nsg+=$_
                }                                                                                     `
            }

    # Get Subnet Level NSG
    $vnets = Az.Network\Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
    foreach ($vnet in $vnets)
    {
        $subnets = Az.Network\Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet
        foreach ($subnet in $subnets)
        {
            foreach ($ipConfiguration in $subnet.IpConfigurations)
            {
                if ($ipConfiguration.Id.Contains($networkInterface))
                {
                    if ($subnet.NetworkSecurityGroup)
                    {
                        $subnetNsgName = Split-Path $subnet.NetworkSecurityGroup.Id -Leaf

                        if ($subnetNsgName)
                        {
                            $subnetNsg = Az.Network\Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $subnetNsgName
                            $nsg+=$subnetNsg
                            break
                        }
                    }
                }
            }
        }
    }

    return $nsg
}

function Get-AzVMPSRemoting
{
    <#
        .DESCRIPTION
        Gets the status of PowerShell Remoting on the given VM

        .PARAMETER Name
        Name of the Azure VM

        .PARAMETER ResourceGroupName
        Name of the Azure resource group

        .PARAMETER Nsg
        Network Security group object

        .EXAMPLE
        Get-AzVMPSRemoting -Name VmName -ResourceGroupName ResourceGroupName -Nsg <nsgObject>
    #>

    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        $Nsg
    )    

    $protocol = @{https = $false; http = $false; ssh = $false}

    if($Nsg){
        # Check if Nsg has inbound allow security rules with protocol (TCP) for WinRM
        Az.Network\Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $Nsg |
            Where-Object { ($_.Access -eq 'Allow') -and ($_.Protocol -eq 'TCP') -and ($_.Direction -eq 'Inbound') -and ($_.SourceAddressPrefix -eq '*') -and ($_.SourcePortRange -eq '*') -and ($_.DestinationAddressPrefix -eq '*') } |
                ForEach-Object {
                    # Port 5985 for http and 5986 for https and 22 for ssh
                    if($_.DestinationPortRange -eq 5986){$protocol.https = $true}
                    if($_.DestinationPortRange -eq 5985){$protocol.http = $true}
                    if($_.DestinationPortRange -eq 22){$protocol.ssh = $true}
                }
    }
    $protocol
}

function Enable-AzVMPSRemoting
{
    <#
        .DESCRIPTION
        Enables the Azure PSRemoting

        .PARAMETER Name
        Specifies the computername

        .PARAMETER ResourceGroupName
        Provide the name of the resource group

        .PARAMETER Protocol
        Provide the type of Protocol for nsg rule setup - http/https/ssh

        .PARAMETER OsType
        Option of windows/linux

        .EXAMPLE
        Enable-AzVMPSRemoting -Name vmName -ResourceGroup resourceGroup

        .EXAMPLE
        Enable-AzVMPSRemoting -Name vmName -ResourceGroup resourceGroup -OsType linux
    #>

    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ResourceGroupName,
                
        [ValidateSet('http','https','ssh')]
        [string]$Protocol,

        [ValidateSet('windows','linux')]
        [OSType]$OsType
    )

    # Since this is a standalone cmdlet and OsType is optional, it may not be supplied
    # So we make a REST call to retrieve the target OsType
    if (-not $OsType)
    {
        $OsType = Get-OsType -Name $Name -ResourceGroupName $ResourceGroupName
    }

    # Obtain all Network Security Groups associated with the VM (Interface level Nsg, Subnet Level Nsg)
    $azVMNsgs = Get-AzVmNsg -Name $Name -ResourceGroupName $ResourceGroupName

    $parameters = @{NetworkSecurityGroup = $null
                        Protocol = 'Tcp'
                        Direction = 'Inbound'
                        Access = 'Allow'
                        SourcePortRange = '*'
                        SourceAddressPrefix = '*'
                        DestinationAddressPrefix = '*'
                        Priority = (Get-Random -Minimum 100 -Maximum 4096)
        }

    $azureVM = Az.Compute\Get-AzVM -Name $Name -ResourceGroupName $ResourceGroupName

    if ([OStype]::Windows -eq $OsType)
    {
        if (-not $Protocol)
        {
            # Only WinRM_HTTPS protocol is supported for Windows Target
            $Protocol = 'https'
        }

        foreach ($azVMNsg in $azVMNsgs)
        {
            # Get PSRemoting status for a given Nsg
            $psremoting = Get-AzVMPSRemoting -Name $Name -ResourceGroupName $ResourceGroupName -Nsg $azVMNsg
            $parameters['NetworkSecurityGroup'] = $azVMNsg

            # If Https is not enabled, enable it
            if($Protocol -eq 'https')
            {
                if (-not $psremoting.Https)
                {                    
                    $null = Az.Network\Add-AzNetworkSecurityRuleConfig -Name 'allow-winrm-https' -DestinationPortRange 5986 @parameters | Az.Network\Set-AzNetworkSecurityGroup
                }
                
                # Setup WinRM HTTPS based remoting using Self-Signed Certificate
                $runCommandParameters =
                @{
                    commandId = 'RunPowerShellScript'
                    script =
                    @(
                        'Set-Item WSMan:\localhost\Service\Auth\Basic $true -Force;$selfSignedCert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName $env:COMPUTERNAME;Enable-PSRemoting -SkipNetworkProfileCheck -Force;Remove-Item -Path WSMan:\Localhost\listener\Listener* -Recurse -Force;New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $selfSignedCert.Thumbprint -Force;New-NetFirewallRule -DisplayName WindowsRemoteManagement_HTTPS_In -Name WindowsRemoteManagement_HTTPS_In -Profile Any -LocalPort 5986 -Protocol TCP -RemoteAddress Any;'
                    )
                }

                $null = Az.Resources\Invoke-AzResourceAction -ResourceId $azureVM.Id -Action runCommand -Parameters $runCommandParameters -ApiVersion 2017-03-30 -Force
            }

            # Future code path, if we support both http/https protocols for Windows target
            # If Http is not enabled, enable it
            if($Protocol -eq 'http')
            {
                if (-not $psremoting.Http)
                {
                    $null = Az.Network\Add-AzNetworkSecurityRuleConfig -Name 'allow-winrm-http' -DestinationPortRange 5985 @parameters | Az.Network\Set-AzNetworkSecurityGroup
                }

                ###################################################################
                # Enable PowerShell remoting on a target Windows computer
                ###################################################################

                # Enable-PSRemoting -Force
                # Enable-PSRemoting configures the computer to receive Windows PowerShell remote commands that are sent by using WSMan protocol
                # Enable-PSRemoting performs the following operations:
                # 1) Runs the Set-WSManQuickConfig cmdlet, to:
                #      Start the WinRM service.
                #      Set the startup type on the WinRM service to Automatic.
                #      Create a listener to accept requests on any IP address.
                #      Enable a firewall exception for WS-Management communications.
                #      Register the Microsoft.PowerShell and Microsoft.PowerShell.Workflow session configurations, if it they are not already registered.
                #      Register the Microsoft.PowerShell32 session configuration on 64-bit computers, if it is not already registered.
                #      Enable all session configurations.
                #      Change the security descriptor of all session configurations to allow remote access.
                # 2) Restart the WinRM service to make the preceding changes effective.

                # Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name  'LocalAccountTokenFilterPolicy' -Value 1 -Type DWord -Force
                # When using local computer account for remoting, UAC (User Account Control) does not allow access to WinRM service.
                # Setting LocalAccountTokenFilterPolicy to 1 ensures UAC filtering for local accounts is disabled and access to WinRM service is granted.
                # Side Note: When using domain account for remoting, this account needs to be a member of the remote computer Administrators group.

                $runCommandParameters =
                @{
                    commandId = 'RunPowerShellScript'
                    script =
                    @(
                        'Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord -Force;Enable-PSRemoting -Force;Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any;'
                    )
                }

                $null = Az.Resources\Invoke-AzResourceAction -ResourceId $azureVM.Id -Action runCommand -Parameters $runCommandParameters -ApiVersion 2017-03-30 -Force
            }
        }
    }
    elseif ([OStype]::Linux -eq $OsType)
    {
        if (-not $Protocol)
        {
            # Only SSH protocol is supported for Linux Target
            $Protocol = 'ssh'
        }

        foreach ($azVMNsg in $azVMNsgs)
        {
            # Get PSRemoting status for a given Nsg
            $psremoting = Get-AzVMPSRemoting -Name $Name -ResourceGroupName $ResourceGroupName -Nsg $azVMNsg
            $parameters['NetworkSecurityGroup'] = $azVMNsg

            # If SSH is not enabled, enable it
            if($Protocol -eq 'ssh')
            {
                if (-not $psremoting.ssh)
                {
                    $null = Az.Network\Add-AzNetworkSecurityRuleConfig -Name 'allow-ssh' -DestinationPortRange 22 @parameters | Az.Network\Set-AzNetworkSecurityGroup
                }

                # ThisRunCommand step does following:
                # 1) Install powershellcore in linux, if not already present
                # 2) backup current sshd_config, configure sshd_config to enable PasswordAuthentication, register powershell subsystem with ssh daemon
                # (#2 is required to support interactive username/password authentication over powershell-ssh)
                # 3) Restart the ssh daemon service to pick up the new config changes            
                $runCommandParameters =
                @{
                    commandId = 'RunShellScript'
                    script =
                    @(
                        'sudo wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb;sudo dpkg -i packages-microsoft-prod.deb;sudo apt-get update;sudo apt-get install -y powershell;sshdconfigfile=/etc/ssh/sshd_config;sudo sed -re "s/^(\#)(PasswordAuthentication)([[:space:]]+)(.*)/\2\3\4/" -i.`date -I` "$sshdconfigfile";sudo sed -re "s/^(PasswordAuthentication)([[:space:]]+)no/\1\2yes/" -i.`date -I` "$sshdconfigfile";subsystem="Subsystem powershell /usr/bin/pwsh -sshs -NoLogo -NoProfile";sudo grep -qF -- "$subsystem" "$sshdconfigfile" || sudo echo "$subsystem" | sudo tee --append "$sshdconfigfile";sudo service sshd restart'
                    )
                }

                $null = Az.Resources\Invoke-AzResourceAction -ResourceId $azureVM.Id -Action runCommand -Parameters $runCommandParameters -ApiVersion 2017-03-30 -Force
            }
        }     
    }    
}

function Disable-AzVMPSRemoting
{
    <#
        .DESCRIPTION
        Disables the Azure PSRemoting

        .PARAMETER Name
        Specifies the computername

        .PARAMETER ResourceGroupName
        Provide the name of the resource group

        .PARAMETER Protocol
        Provide the type of Protocol for nsg rule setup - http/https/ssh

        .PARAMETER OsType
        Option of windows/linux

        .EXAMPLE
        Disable-AzVMPSRemoting -Name VmName -ResourceGroup resourceGroup

        .EXAMPLE
        Disable-AzVMPSRemoting -Name VmName -ResourceGroup resourceGroup -Protocol http -OsType windows

        .EXAMPLE
        Disable-AzVMPSRemoting -Name VmName -ResourceGroup resourceGroup -Protocol ssh -OsType linux
    #>

    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ResourceGroupName,

        [ValidateSet('http','https','ssh')]
        [string]$Protocol,

        [ValidateSet('windows','linux')]
        [OSType]$OsType
    )

    # Since this is a standalone cmdlet and OsType is optional, it may not be supplied
    # So we make a REST call to retrieve the target OsType
    if (-not $OsType)
    {
        $OsType = Get-OsType -Name $Name -ResourceGroupName $ResourceGroupName
    }
    
    $azVMNsgs = Get-AzVmNsg -Name $Name -ResourceGroupName $ResourceGroupName

    if ([OStype]::Windows -eq $OsType)
    {
        if (-not $Protocol)
        {
            # Only WinRM_HTTPS protocol is supported for Windows Target
            $Protocol = 'https'
        }

        foreach ($azVMNsg in $azVMNsgs)
        {
            #Check if Nsg has allow security rules for port (5986 or 5985) and protocol (TCP) for WinRM
            Az.Network\Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $azVMNsg |
                Where-Object {($_.Access -eq 'Allow') -and ($_.Protocol -eq 'TCP') -and ($_.Direction -eq 'Inbound') } |
                    ForEach-Object {
                        if(
                            (($Protocol -eq 'http') -and ($_.DestinationPortRange -eq 5985)) -or
                            (($Protocol -eq 'https') -and ($_.DestinationPortRange -eq 5986))
                        ){
                            $null = Az.Network\Remove-AzNetworkSecurityRuleConfig -Name $_.Name -NetworkSecurityGroup $azVMNsg | Az.Network\Set-AzNetworkSecurityGroup
                        }
                    }
        }

        # Disable PowerShell Remoting and restore UAC (User Account Control) setting
        $azureVM = Az.Compute\Get-AzVM -Name $Name -ResourceGroupName $ResourceGroupName
        $parameters =
        @{
            commandId = 'RunPowerShellScript'
            script =
            @(
                "Disable-PSRemoting -Force; Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name LocalAccountTokenFilterPolicy -Value 0 -Type DWord -Force;"
            )
        }

        $null = Az.Resources\Invoke-AzResourceAction -ResourceId $azureVM.Id -Action runCommand -Parameters $parameters -ApiVersion 2017-03-30 -Force
    }
    elseif ([OStype]::Linux -eq $OsType)
    {
        if (-not $Protocol)
        {
            # Only SSH protocol is supported for Linux Target
            $Protocol = 'ssh'
        }

        foreach ($azVMNsg in $azVMNsgs)
        {
            # Remove Allow-ssh inbound rule for TCP, Port 22
            Az.Network\Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $azVMNsg |
                Where-Object {($_.Access -eq 'Allow') -and ($_.Protocol -eq 'TCP') -and ($_.Direction -eq 'Inbound') } |
                    ForEach-Object {
                        if(
                            (($Protocol -eq 'ssh') -and ($_.DestinationPortRange -eq 22))
                        ){
                            $null = Az.Network\Remove-AzNetworkSecurityRuleConfig -Name $_.Name -NetworkSecurityGroup $azVMNsg | Az.Network\Set-AzNetworkSecurityGroup
                        }
                    }
        }

        # Restore to original SSH Daemon Config, restart sshd service to pick the config
        $azureVM = Az.Compute\Get-AzVM -Name $Name -ResourceGroupName $ResourceGroupName
        $parameters =
        @{
            commandId = 'RunShellScript'
            script =
            @(
                'sudo cp -f /etc/ssh/sshd_config_orig /etc/ssh/sshd_config;sudo service sshd restart'
            )
        }

        $null = Az.Resources\Invoke-AzResourceAction -ResourceId $azureVM.Id -Action runCommand -Parameters $parameters -ApiVersion 2017-03-30 -Force
    }
}

function Get-AzCommand
{
    <#
        .DESCRIPTION
        Gets the Azure Command relevant to the current path

        .PARAMETER Keyword
        Specifies the keyword to be used to find the Az Command

        .EXAMPLE
        Get-AzCommand

        Get-AzCommand -Keyword azureKeyWord
    #>

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$false)]
        [string]$Keyword
    )

    if($Keyword) {
        return GetCommand -Keyword $Keyword.ToLower()
    }

    $path = (Get-Location).Path
    $array = $path.Split([System.IO.Path]::DirectorySeparatorChar,[System.StringSplitOptions]::RemoveEmptyEntries)
    $start = $array.Count - 1
    for($index = $start; $index -gt 1 ; $index--){
        $curr = $array[$index]
        $str = $curr -replace ':'
        # Remove the Preceding 'Microsoft.'
        if($str.ToLower().StartsWith("microsoft.")) {
            $str = $str.ToLower() -replace "microsoft."
        }
        # If the string is a plural (ends with a s)
        # Remove the last s
        # Some cmdlets have singular names in them
        $str = $str.ToLower().TrimEnd('s')

        $commands = GetCommand -Keyword $str
        if($commands) {
            return $commands
        }
    }

    # Generic help
    $commands = GetCommand
    return $commands
}

function Test-AzResourceGroup
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName
    )

    # Check if the resourcegroup exists
    $resourceGroup = Az.Resources\Get-AzResource -ErrorAction SilentlyContinue | Where-Object {$_.ResourceGroupName -eq $ResourceGroupName}
    if(-not $resourceGroup) {
        return $false
    }

    $verboseMessage = $LocalizedData.TestResourceGroup -f ($ResourceGroupName)
    Write-Verbose -Message $verboseMessage

    return $true
}

function Test-AzVM
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [OSType]$OsType        
    )

    $azVMNsgs = Get-AzVmNsg -Name $Name -ResourceGroupName $ResourceGroupName

    foreach ($azVMNsg in $azVMNsgs)
    {
        # Check if Remoting is enabled for the VM
        $psRemoting = Get-AzVMPSRemoting -Name $Name -ResourceGroupName $ResourceGroupName -Nsg $azVMNsg

        if ((([OStype]::Windows -eq $OsType) -and (-not $psRemoting.https)) -or (([OStype]::Linux -eq $OsType) -and (-not $psRemoting.ssh)))
        {            
            $errMsg = $LocalizedData.TestAzPsRemotingError -f ($Name, $ResourceGroupName)
            throw $errMsg            
        }       
    }

    # Check the communication with the remote machine
    $cName = Get-AzVMPublicIPAddress -Name $Name -ResourceGroupName $ResourceGroupName
    if ($cName)
    {
        return $cName
    }

    return $null
}

#endregion

#region Common Functions
function Get-OsType
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName

    )

    $vmInfo = Az.Compute\Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Name
    if(-not $vmInfo) {
        $message = $LocalizedData.GetAzureVMError -f ($Name)
        throw [System.ArgumentException] $message
    }

    if ($vmInfo.OSProfile.WindowsConfiguration)
    {
        return [OStype]::Windows
    }
    elseif ($vmInfo.OSProfile.LinuxConfiguration)
    {
        return [OStype]::Linux
    }

    return $null
}

function Get-Help {

    [CmdletBinding(DefaultParameterSetName='AllUsersView', HelpUri='http://go.microsoft.com/fwlink/?LinkID=113316')]
    param(
        [Parameter(Position=0, ValueFromPipelineByPropertyName=$true)]
        [string]$Name,

        [string]$Path,

        [ValidateSet('Alias','Cmdlet','Provider','General','FAQ','Glossary','HelpFile','ScriptCommand','Function','Filter','ExternalScript','All','DefaultHelp','Workflow','DscResource','Class','Configuration')]
        [string[]]$Category,

        [string[]]$Component,

        [string[]]$Functionality,

        [string[]]$Role,

        [Parameter(ParameterSetName='DetailedView', Mandatory=$true)]
        [switch]$Detailed,

        [Parameter(ParameterSetName='AllUsersView')]
        [switch]$Full,

        [Parameter(ParameterSetName='Examples', Mandatory=$true)]
        [switch]$Examples,

        [Parameter(ParameterSetName='Parameters', Mandatory=$true)]
        [string]$Parameter,

        [Parameter(ParameterSetName='Online', Mandatory=$true)]
        [switch]$Online
    )

    # If this function is called without -Name parameter, then show Cloud Shell help
    if (-not $Name) {
        $helpFilePath = Join-Path $PSScriptRoot "PSCloudShellUtility.Help.txt"
        if(Test-Path -Path $helpFilePath) {
            Get-Content -Path $helpFilePath
        }
    }

    # For all other cases, call built-in Get-Help cmdlet
    else{
        if (($Name -eq "get-help") -and (-not $Category)){
            $PSBoundParameters['Name'] = "Microsoft.PowerShell.Core\Get-Help";
        }

        if($Online) {
            RedirectOnlineHelp $PSBoundParameters
        } else {
            Microsoft.PowerShell.Core\Get-Help @PSBoundParameters
        }
    }

<#

.ForwardHelpTargetName Get-Help
.ForwardHelpCategory Cmdlet

#>

}

function ThrowError
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,

        [System.Object]
        $ExceptionObject,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $exception = New-Object $ExceptionName $ExceptionMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $ErrorCategory, $ExceptionObject
    $CallerPSCmdlet.ThrowTerminatingError($errorRecord)
}

function GetCommand {
    param (
        [parameter(Mandatory = $false)]
        $Keyword
    )

    if(-not $Keyword) {
        $commands = Get-Command -Module Az.*
        return $commands
    }

    if(-not $script:acronymLookup) {
        $acronymContent = GetAcronymContent
        if(-not $acronymContent) {
            return $null
        }
        $script:acronymLookup = @{}
        $acronymContent.psobject.properties | ForEach-Object {
            $script:acronymLookup[$_.Name] = $_.Value
        }
    }

    $currKeyWord = if($script:acronymLookup.ContainsKey($Keyword)) {
                        $script:acronymLookup.$Keyword
                   } else {
                        $Keyword
                   }

    $currKeyWord = "*$currKeyWord*"
    $commands = Get-Command -Module Az.* -Name $currKeyWord -ErrorAction SilentlyContinue
    return $commands
}

function GetAcronymContent 
{
    # Get the acronyms file
    $path = Join-Path -Path $PSScriptRoot -ChildPath 'PSCloudShellUtilityAcronyms.json'

    if(Test-Path -Path $path) {
        # Get the content from the acronyms file
        $content = Get-Content -Path $path | ConvertFrom-Json
        return $content
    }

    return $null
}

function RedirectOnlineHelp($Parameters)
{   
    try {
        Microsoft.PowerShell.Core\Get-Help @Parameters
    }
    catch [System.Management.Automation.PSInvalidOperationException]
    {
        $err = $_
        $matchFound = $err.Exception.Message -match "No program or browser is associated to open the URI (?<link>\w+:\/\/[\w@][\w.:@]+\/?[\w\.?=%&=\-@/$,]*)."
        
        if(($matchFound -eq $True) -and (-not [string]::IsNullOrEmpty($env:ACC_TERM_ID))) {
            $targetLink = $matches["link"]
            Write-Verbose "Redirecting to $targetLink"

            $uri = "http://localhost:8888/openLink/$($env:ACC_TERM_ID)"	
        
            try{
                $null = Invoke-RestMethod -Method Post -Uri $uri -Body "{""url"":""$targetLink""}" -ContentType "application/json"
            }catch{
                Write-Warning -Message "Redirecting to $targetLink failed, please open the link in another page." 
                throw
            }
        }
        else {
            # If the failure was caused by other reason, just throw it AS-IS.
            throw
        }
    }
}

function New-PackageInfo() {
    param(
        [string]$name,
        [string]$version,
        [string]$type
    )
    return [PSCustomObject]@{
        Name    = $name
        Version = $version
        Type    = $type
    }
}

function Get-PackageVersion() {
    <#
        .DESCRIPTION
        Report versions of all installed packages

        .EXAMPLE
        Get-PackageVersion | Where-Object Name -like "*emacs*"
    #>
    [CmdletBinding()]
    param()

    # Apt and some other programs write to stderr, which fails tests without this
    $ErrorActionPreference = "Continue"
    
    # Enumerate all APT packages with versions
    $packages = New-Object -TypeName System.Collections.ArrayList

    # TODO - find the regular expression to seperate the package name from the package version
    # apt list --installed 2> /dev/null | % { 
    #     Write-Verbose "Apt: $_"
    #     if ($_ -match "([^/]*)/[^ ]* ([^ ]*)") { 
    #         $p = New-PackageInfo -Name $matches[1] -Version $matches[2] -Type "Apt"
    #         $null = $packages.Add($p)
    #     }
    # }

    # enumerate special packages
    $pwsh = New-PackageInfo -Name "PowerShell" -Version $PSVersionTable.PSVersion.ToString() -type "Special"
    $null = $packages.Add($pwsh)

    function Get-VersionFromCommand($package) {
        try {
            $output = Invoke-Expression "& $($package.command) $($package.Args) 2>/dev/null"
        }
        catch {
            return "Error"
        }
                
        $version = ($output | % {
                if ($_ -match $package.match) {
                    Write-Verbose "matched $_"
                    $matches[1];
                }
            })
        if ($null -eq $version) { $version = "Unknown"}
        return $version
    }

    $packageVersionDetections = @(
        @{displayname = "Node.JS"; command = "node"; args = "--version"; match = "v(.*)"},
        @{displayname = "Cloud Foundry CLI"; command = "cf"; args = "-v"; match = "cf version (.*)"},
        @{displayname = "Blobxfer"; command = "blobxfer"; args = "--version"; match = "blobxfer, version (.*)"},
        @{displayname = "Batch Shipyard"; command = "shipyard"; args = "--version"; match = "shipyard.py, version (.*)"},
        @{displayname = "Ansible"; command = "ansible"; args = "--version"; match = "ansible \[core ([\d\.]+)\]"},
        @{displayname = "Istio"; command = "istioctl"; args = "version -s --remote=false"; match = "(.+)"},
        @{displayname = "Linkerd"; command = "linkerd"; args = "version --client --short"; match = "(stable-[\d\.]+)"},
        @{displayname = "Go"; command = "go"; args = "version"; match = "go version go(\S+) .*"},
        @{displayname = "Packer"; command = "packer"; args = "version"; match = "Packer v(.+)"},
        @{displayname = "DC/OS CLI"; command = "dcos"; args = "--version"; match = "dcoscli.version=(.*)"},
        @{displayname = "Ripgrep"; command = "rg"; args = "--help | head"; match = "ripgrep ([\d\.]+)$"},
        @{displayname = "Helm"; command = "helm"; args = "version --short"; match = "v(.+)"},
        @{displayname = "AZCopy"; command = "azcopy"; args = "--version"; match = "azcopy version (.+)"},
        @{displayname = "Azure CLI"; command = "az"; args = "version "; match = "`"azure-cli`": `"(.+)`""},
        @{displayname = "Kubectl"; command = "kubectl"; args = "version --client=true --short=true"; match = "Client Version: v(.+)"}
        @{displayname = "Terraform"; command = "terraform"; args = "version"; match = "Terraform v(.+)"},
        @{displayname = "GitHub CLI"; command = "gh"; args = "--version"; match = "gh version (.+) \(.*"},
        @{displayname = "Azure Developer CLI"; command = "azd"; args = "version"; match = "azd version \d+\.\d+\.\d+(-[\w\d\.]*)?"}
    )

    foreach ($package in $packageVersionDetections) {
        Write-Verbose "$($package.displayname)"
        $version = Get-VersionFromCommand -Package $package
        $p = New-PackageInfo -Name $package.displayname -Version $version -type "Special"
        $null = $packages.Add($p)
    }

    # PIP3 packages
    & pip3 list | % { 
        if ($_ -match "(\w+)\s+(.*)") { 
            $p = New-PackageInfo -Name $matches[1] -Version $matches[2] -Type "PIP"
            $null = $packages.Add($p)
        }
    }

    # TODO Ruby Gems
    # $rubypackages = [ordered]@{}
    # & gem list --local | % { if ($_ -match "(\w+)\s+\((.*)\)") { $pippackages[$matches[1]] = $matches[2]}}}

    # PowerShell modules
    Get-Module -ListAvailable | % {
        $p = New-PackageInfo -name $_.Name -version $_.Version -type "PowerShell"
        $null = $packages.Add($p)
    }

    # NPM global modules


    $packages | sort-object -Property Type, Name
}
