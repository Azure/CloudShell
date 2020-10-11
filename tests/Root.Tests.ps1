Import-Module Pester

Describe "Tests that check things not available to the limited user" {

    It "Powershell warmup script is available and works" {

        Test-Path "/usr/cloudshell/linux/powershell/Invoke-PreparePowerShell.ps1"  | Should -Be $true
        Invoke-Expression -Command "/usr/cloudshell/linux/powershell/Invoke-PreparePowerShell.ps1" -ErrorVariable myerr
        $myerr | Should -BeNullOrEmpty
    }
}
