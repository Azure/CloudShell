Describe "Various programs installed with expected versions" {
 
    BeforeAll {
        $script:packages = Get-PackageVersion
        $script:pmap = @{}
        $script:packages | % {
            $script:pmap[$_.Name] = $_
        }
    }

    It "Base OS - CBL-Mariner 2.0" {

        [System.Environment]::OSVersion.Platform | Should -Be 'Unix'
        $osDetails = Get-Content /etc/*release
        $osDetails | Where-Object {$_.Contains('VERSION_ID="2.0"')} | Should -Not -BeNullOrEmpty
        $osDetails | Where-Object {$_.Contains('NAME="Common Base Linux Mariner"')} | Should -Not -BeNullOrEmpty
    }

    It "Static Versions" {
        # These programs are installed explicitly with specific versions
        $script:pmap["Node.JS"].Version | Should -Be '16.14.2'
        $script:pmap["PowerShell"].Version | Should -BeLike '7.2*'        
    }

    It "Some Versions Installed" {
        # These programs are not pinned to exact versions, we just check they are still installed and 
        # running the version command works
        
        $script:packages | ? Type -eq "Special" | % {
            $name = $_.Name
            $_.Version | Should -Not -BeNullOrEmpty -Because "$name should be present"
            $_.Version | Should -Not -Be "Error" -Because "Error occurred running $name to determine version"
            $_.Version | Should -Not -Be "Unknown" -Because "Could not parse version info for $name"
        }
    }

    It "startupscript" {
        $pwshPath = which pwsh
        $startupScriptPath = Join-Path (Split-Path $pwshPath) 'PSCloudShellStartup.ps1'
        Test-Path $startupScriptPath | Should -Be $true
    }

    It "az cli extensions" {
        az extension list | jq '.[] | .name' | Should -Contain '"ai-examples"'
    }

    It "Compare bash commands to baseline" {
        # command_list contains a list of all the files which should be installed
        $command_diffs = bash -c "compgen -c | sort -u > /tests/installed_commands && diff -w /tests/command_list /tests/installed_commands"
        # these may or may not be present depending on how tests were invoked
        $special = @(
            "profile.ps1", 
            "PSCloudShellStartup.ps1", 
            "dh_pypy", 
            "dh_python3", 
            "pybuild", 
            "python3-config", 
            "python3m-config", 
            "x86_64-linux-gnu-python3-config", 
            "x86_64-linux-gnu-python3m-config",
            "linkerd-stable.*",
            "pwsh-preview"
        )

        $specialmatcher = ($special | % { "($_)"}) -join "|"

        $missing = ($command_diffs | ? { $_ -like "<*" } | % { $_.Replace("< ", "") } | ? { $_ -notmatch $specialmatcher}) -join ","        
        $missing | Should -Be "" -Because "Commands '$missing' should be installed on the path but were not found. No commands should have been removed unexpectedly. If one really should be deleted, remove it from command_list"

        $added = ($command_diffs | ? { $_ -like ">*" } | % { $_.Replace("> ", "") } | ? { $_ -notmatch $specialmatcher}) -join ","
        $added | Should -Be "" -Because "Commands '$added' were unexpectedly found on the path. Probably this is good, in which case add them to command_list"

    }

    It "has local paths in `$PATH" {
        $paths = ($env:PATH).split(":")
        $paths | Should -Contain "~/bin"
        $paths | Should -Contain "~/.local/bin"
    }

    It "Ansible pwsh has modules" {
        Test-Path -Path "/usr/share/ansible/collections/ansible_collections/azure/azcollection/" | Should -Be $true
        $process = Start-Process -FilePath /opt/ansible/bin/python -ArgumentList "-c `"import msrest`"" -Wait -PassThru
        $process.ExitCode | Should -Be 0
    }

    It "Has various environment vars" {
        $env:AZUREPS_HOST_ENVIRONMENT | Should -Be "cloud-shell/1.0"
    }
}

Describe "PowerShell Modules" {

    BeforeAll {

        # set SkipAzInstallationChecks to avoid az check for AzInstallationChecks.json
        [System.Environment]::SetEnvironmentVariable('SkipAzInstallationChecks', $true)
        
    }

    It "Single version of Modules are installed" {

        # Ensure only one version of every single module is installed
        # This test is required since we are pulling modules from multiple repositories and the modules themselves have interconnected dependencies

        $special = @("PSReadLine")

        (Get-Module -ListAvailable | Group-Object Name | Where-Object { $_.Count -gt 1 } ) | Where-Object { $_.Name -notin $special} | Should -Be $null

    }

    It "Az PowerShell Module" {

        $module = Get-InstalledModule -Name Az -AllVersions
        $module | Should -Not -BeNullOrEmpty

        # Verify Az module version
        $module.Version -ge [version]"5.0" | Should -Be $true

    }

    It "Az.Accounts PowerShell Module" {

        $module = Get-InstalledModule -Name Az.Accounts -AllVersions
        $module | Should -Not -BeNullOrEmpty
    }

    It "Az.Resources PowerShell Module" {

        $module = Get-InstalledModule -Name Az.Resources -AllVersions
        $module | Should -Not -BeNullOrEmpty
    }

    It "SHiPS PowerShell Module" {

        $module = Get-InstalledModule -Name SHiPS -AllVersions
        $module | Should -Not -BeNullOrEmpty
        $module.Repository | Should -Be "PSGallery"

        # SHiPS module version must be 0.*.*.* or greater
        $module.Version -like "0.*.*" | Should -Be $true

    }

    It "AzurePSDrive PowerShell Module" {

        # AzurePSDrive was copied to Modules path, instead of installing from PSGallery
        # Due to Gallery limitation of handling FullClr/CoreClr dependencies
        # See https://msazure.visualstudio.com/One/_queries/edit/2364469/?fullScreen=false
        $module = Get-Module -Name AzurePSDrive -ListAvailable
        $module | Should -Not -BeNullOrEmpty        

        # AzurePSDrive module version must be 0.9.*.* or greater
        $module.Version.Major -eq 0 | Should -Be $true
        $module.Version.Minor -ge 9 | Should -Be $true

    }

    It "PSCloudShellUtility PowerShell Module" {

        $module = Get-Module -Name PSCloudShellUtility -ListAvailable
        $module | Should -Not -BeNullOrEmpty

        # PSCloudShellUtility module version must be 0.*.*.* or greater
        $module.Version -like "0.*.*" | Should -Be $true

    }

    It "EXOConnector PowerShell Module" {

        $module = Get-Module -Name EXOPSSessionConnector -ListAvailable
        $module | Should -Not -BeNullOrEmpty

        # EXOPSSessionConnector module should have at least one command
        (Get-Command * -Module EXOPSSessionConnector).Count -ge 1 | Should -Be $true        
    }

    It "PowerBI PowerShell Module" {

        $module = Get-Module -Name MicrosoftPowerBIMgmt -ListAvailable
        $module | Should -Not -BeNullOrEmpty

        # MicrosoftPowerBIMgmt module version must be 1.*.* or greater
        $module.Version -like "1.*.*" | Should -Be $true

    }

    It "GuestConfiguration PowerShell Module" {

        $module = Get-Module -Name GuestConfiguration -ListAvailable
        $module | Should -Not -BeNullOrEmpty

        # GuestConfiguration module version must be 0.*.* or greater
        $module.Version -like "4.*.*" | Should -Be $true
    }

    It "MicrosoftTeams PowerShell Module" {

        $module = Get-Module -Name MicrosoftTeams -ListAvailable
        $module | Should -Not -BeNullOrEmpty

        # MicrosoftTeams module should have at least one command
        (Get-Command * -Module MicrosoftTeams).Count -ge 1 | Should -Be $true        
    }

    It "Microsoft.PowerShell.UnixCompleters PowerShell Module" {
        $module = Get-Module -Name Microsoft.PowerShell.UnixCompleters -ListAvailable
        $module | Should -Not -BeNullOrEmpty

    }
    
    It "Microsoft.PowerShell.SecretManagement PowerShell Module" {
        
        $module = Get-Module -Name 'Microsoft.PowerShell.SecretManagement' -ListAvailable
        $module | Should -Not -BeNullOrEmpty

    }
    
    It "Microsoft.PowerShell.SecretStore PowerShell Module" {
        
        $module = Get-Module -Name 'Microsoft.PowerShell.SecretStore' -ListAvailable
        $module | Should -Not -BeNullOrEmpty

    }

    $importModuleTestCases = @(
        @{ ModuleName = "Microsoft.PowerShell.Management" }
        @{ ModuleName = "PSCloudShellUtility" }
        @{ ModuleName = "SHiPS" }
        @{ ModuleName = "AzureAD.Standard.Preview" }
        @{ ModuleName = "Az" }
        @{ ModuleName = "MicrosoftPowerBIMgmt" }
        @{ ModuleName = "GuestConfiguration" }
        @{ ModuleName = "EXOPSSessionConnector" }
        @{ ModuleName = "MicrosoftTeams" }
        @{ ModuleName = "Microsoft.PowerShell.UnixCompleters" }
        @{ ModuleName = "Microsoft.PowerShell.SecretManagement" }
        @{ ModuleName = "Microsoft.PowerShell.SecretStore" }
    )

    It "Import-Module test for <ModuleName>" -TestCases $importModuleTestCases {

        param($ModuleName)
        try {
            Import-Module $ModuleName -Force -ErrorAction Stop -ErrorVariable ev
            $ev | Should -BeNullOrEmpty
        }
        catch {
            "Unexpected exception thrown: $_" | Should -BeNullOrEmpty
        }

    }

    It "Initialize AzureAD.Standard.Preview Module" {

        try {
            # Connect-AzureAD must return success even without a valid MSI endpoint
            # TenantDomain will not be resolved in this case
            # The actual token retrieval happens when a AD call (such as Get-AzureADUser) is made
            AzureAD.Standard.Preview\Connect-AzureAD -Identity -TenantId 0
        }
        catch {
            "Unexpected exception thrown: $_" | Should -BeNullOrEmpty
        }

    }

}
