Import-Module Pester

Describe "Tests that check things not available to the limited user" -Tag "RootUser" {

    It "Powershell warmup script is available and works" {

        Test-Path "/usr/cloudshell/linux/powershell/Invoke-PreparePowerShell.ps1"  | Should-BeTrue
        Invoke-Expression -Command "/usr/cloudshell/linux/powershell/Invoke-PreparePowerShell.ps1" -ErrorVariable myerr
        $myerr | Should-BeFalsy
    }
}
