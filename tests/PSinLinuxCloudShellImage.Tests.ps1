Describe "Various programs installed with expected versions" {

    It "Base OS - CBL-D 10" {

        [System.Environment]::OSVersion.Platform | Should -Be 'Unix'
        $osDetails = Get-Content /etc/*release
        $osDetails | Where-Object {$_.Contains('VERSION_ID="10"')} | Should -Not -BeNullOrEmpty
        $osDetails | Where-Object {$_.Contains('NAME="Common Base Linux Delridge"')} | Should -Not -BeNullOrEmpty
    }

    It "nodejs" {
        Test-Path -Path '/usr/local/bin/nodejs'| Should -Be $true
        $nodeVersion = nodejs --version 
        $nodeVersion.Contains('v8.16.0') | Should -Be $true
    }

    It "Jenkins client" {
        $jxVersion = jx --version 
        $jxVersion.Contains('1.3.107') | Should -Be $true
    }

    It "CloudFoundry CLI" {
        $cfVersion = cf --version
        $cfVersion | Where-Object {$_ -like 'cf version 6.*' } | Should -Be $true
    }

    It "blobxfer" {
        $blobxferVersion = blobxfer --version 
        $blobxferVersion | Where-Object {$_ -like 'blobxfer, version 1.*' } | Should -Be $true
    }

    It "shipyard" {
        $shipyardVersion = shipyard --version 
        $shipyardVersion | Where-Object {$_ -like "shipyard.py, version 3.*"} | Should -Be $true
    }

    It "ansible" {
        $ansibleVersion = ansible --version
        # Match only major version. Any change in major version is considered potentially breaking
        $ansibleVersion | Where-Object {$_ -like "ansible 2.*.*"} | Should -Be $true
    }

    It "puppet bolt" {
        $boltVersion = bolt --version
        $boltVersion | Where-Object {$_ -like "2.*"} | Should -Be $true
    }

    It "Go lang" {
        $goVersion = go version
        $goVersion | Where-Object {$_ -like '*go1.13.7*' } | Should -Be $true
    }

    It "Ruby" {
        $rubyVersion = ruby --version 
        $rubyVersion | Where-Object {$_ -like 'ruby 2.5.*' } | Should -Be $true
    }

    It "Packer" {
        $packerVersion = packer --version
        $packerVersion | Where-Object {$_ -like '1.*' } | Should -Be $true
    }

    It "dcos" {
        $dcosVersion = dcos --version 
        $dcosVersion | Where-Object {$_ -like 'dcoscli.version=1.*' } | Should -Be $true
    }

    It "kubectl" {
        # We auto-upgrade so only check major version here
        $kubectlVersion = kubectl version --client -o json | jq .clientVersion.major
        $kubectlVersion | Should -Be '"1"'
    }

    It "rg" {
        $rgVersion = rg --version 
        $rgVersion | Where-Object {$_ -like 'ripgrep 12.*' } | Should -Be $true
    }

    It "helm" {
        $helmVersion = helm version
        $helmVersion | Where-Object {$_ -like 'version.BuildInfo{Version:"v3*' } | Should -Be $true
    }

    It "draft" {
        $draftVersion = draft version -s
        $draftVersion | Where-Object {$_ -like 'v0.16*' } | Should -Be $true
    }

    It "startupscript" {
        $pwshPath = which pwsh
        $startupScriptPath = Join-Path (Split-Path $pwshPath) 'PSCloudShellStartup.ps1'
        Test-Path $startupScriptPath | Should -Be $true
    }

    It "azcli" {

        $azCliVersion = az --version
        # Match only major version. Any change in major version is considered potentially breaking
        # Output example: azure-cli                         2.0.58
        $azCliVersion | Where-Object {$_ -like "azure-cli*2.*.*"} | Should -Be $true
    }

    It "az cli extensions" {
        az extension list | jq '.[] | .name' | Should -Contain '"ai-examples"'
    }

    It "docker-client, docker-machine" {

        # Match only major version. Any change in major version is considered potentially breaking
        $dockerVersion = docker --version
        $dockerVersion | Where-Object {$_ -like "Docker version 19.*.*, build *"} | Should -Be $true

        $dockerMachineVersion = docker-machine --version
        $dockerMachineVersion | Where-Object {$_ -like "docker-machine version 0.*.*, build *"} | Should -Be $true
    }

    It "terraform" {

        $terraformVersion = terraform --version

        # Match only major version. Any change in major version is considered potentially breaking
        $terraformVersion | Where-Object {$_ -like "Terraform v0.*.*"} | Should -Be $true
    }

    It "github CLI" {
        Invoke-Expression -Command 'gh' -ErrorVariable myerr
        $myerr | Should -BeNullOrEmpty
    }

    It "Compare bash commands to baseline" {
        # command_list contains a list of all the files which should be installed
        $command_diffs = bash -c "compgen -c | sort -u > /tests/installed_commands && diff /tests/command_list /tests/installed_commands"

        # these may or may not be present depending on how tests were invoked
        $special = @("profile.ps1", "PSCloudShellStartup.ps1", "dh_pypy", "dh_python3", "pybuild", "python3-config", "python3m-config", "x86_64-linux-gnu-python3-config", "x86_64-linux-gnu-python3m-config")

        $missing = ($command_diffs | ? { $_ -like "<*" } | % { $_.Replace("< ", "") } | ? { $_ -notin $special}) -join ","        
        $missing | Should -Be "" -Because "Commands '$missing' should be installed on the path but were not found. No commands should have been removed unexpectedly. If one really should be deleted, remove it from command_list"

        $added = ($command_diffs | ? { $_ -like ">*" } | % { $_.Replace("> ", "") } | ? { $_ -notin $special}) -join ","
        $added | Should -Be "" -Because "Commands '$added' were unexpectedly found on the path. Probably this is good, in which case add them to command_list"

    }

    It "has local paths in `$PATH" {
        $paths = ($env:PATH).split(":")
        $paths | Should -Contain "~/bin"
        $paths | Should -Contain "~/.local/bin"
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
        (Get-Module -ListAvailable | Group-Object Name | Where-Object { $_.Count -gt 1 } ) | Should -Be $null

    }

    It "Az PowerShell Module" {

        $module = Get-InstalledModule -Name Az -AllVersions
        $module | Should -Not -BeNullOrEmpty
        $module.Repository | Should -Be "https://www.poshtestgallery.com/api/v2"

        # Verify Az module version
        $module.Version -ge [version]"5.0" | Should -Be $true

    }

    It "Az.Accounts PowerShell Module" {

        $module = Get-InstalledModule -Name Az.Accounts -AllVersions
        $module | Should -Not -BeNullOrEmpty
        $module.Repository | Should -Be "https://www.poshtestgallery.com/api/v2"
    }

    It "Az.Resources PowerShell Module" {

        $module = Get-InstalledModule -Name Az.Resources -AllVersions
        $module | Should -Not -BeNullOrEmpty
        $module.Repository | Should -Be "https://www.poshtestgallery.com/api/v2"
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

    It "Az.GuestConfiguration PowerShell Module" {

        $module = Get-Module -Name Az.GuestConfiguration -ListAvailable
        $module | Should -Not -BeNullOrEmpty

        # Az.GuestConfiguration module version must be 0.*.* or greater
        $module.Version -like "0.*.*" | Should -Be $true
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

    $importModuleTestCases = @(
        @{ ModuleName = "Microsoft.PowerShell.Management" }
        @{ ModuleName = "PSCloudShellUtility" }
        @{ ModuleName = "SHiPS" }
        @{ ModuleName = "AzureAD.Standard.Preview" }
        @{ ModuleName = "Az" }
        @{ ModuleName = "MicrosoftPowerBIMgmt" }
        @{ ModuleName = "Az.GuestConfiguration" }
        @{ ModuleName = "EXOPSSessionConnector" }
        @{ ModuleName = "MicrosoftTeams" }
        @{ ModuleName = "Microsoft.PowerShell.UnixCompleters" }
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
