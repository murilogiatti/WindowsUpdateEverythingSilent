Describe "Cleanup Script - Windows Update Module Checks" {
    BeforeAll {
        function sfc {}
        function DISM {}
        function winget {}
        function usoclient { param($Action) }
        function Stop-Service {}
        function Start-Service {}
        function Clear-RecycleBin {}
        function ipconfig {}
        function netsh {}
        function Optimize-Volume {}
        function Get-WindowsUpdate { param([switch]$AcceptAll, [switch]$Install, $AutoReboot) }
    }

    BeforeEach {
        Mock Stop-Service {}
        Mock Start-Service {}
        Mock Clear-RecycleBin {}
        Mock DISM {}
        Mock sfc {}
        Mock ipconfig {}
        Mock netsh {}
        Mock winget {}
        Mock usoclient {}
        Mock Optimize-Volume {}
        Mock Write-Host {}
        Mock Get-ChildItem {}
        Mock Remove-Item {}
        Mock Test-Path { return $false }
        Mock Import-Module {}
        Mock Get-WindowsUpdate {}
    }

    It "Should use PSWindowsUpdate if the module is available" {
        Mock Get-Module { return @{Name="PSWindowsUpdate"} } -ParameterFilter { $Name -eq 'PSWindowsUpdate' }

        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        Assert-MockCalled Import-Module -ParameterFilter { $Name -eq 'PSWindowsUpdate' } -Times 1 -Exactly
        Assert-MockCalled Get-WindowsUpdate -ParameterFilter { $AcceptAll -and $Install -and ($AutoReboot -eq $false) } -Times 1 -Exactly
        Assert-MockCalled usoclient -Times 0
    }

    It "Should use usoclient if PSWindowsUpdate module is missing" {
        Mock Get-Module { return $null } -ParameterFilter { $Name -eq 'PSWindowsUpdate' }

        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        Assert-MockCalled Import-Module -ParameterFilter { $Name -eq 'PSWindowsUpdate' } -Times 0
        Assert-MockCalled Get-WindowsUpdate -Times 0
        Assert-MockCalled usoclient -Times 3 -Exactly

        Assert-MockCalled usoclient -ParameterFilter { $Action -eq 'StartScan' } -Times 1 -Exactly
        Assert-MockCalled usoclient -ParameterFilter { $Action -eq 'StartDownload' } -Times 1 -Exactly
        Assert-MockCalled usoclient -ParameterFilter { $Action -eq 'StartInstall' } -Times 1 -Exactly
    }
}
