BeforeAll {
    $sysDir = if ($env:windir) { "$env:windir\System32" } else { "C:\Windows\System32" }
    $wingetPath = if ($env:LOCALAPPDATA) { "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" } else { "C:\Users\Default\AppData\Local\Microsoft\WindowsApps\winget.exe" }

    # Stub external commands and standard cmdlets that might not exist on the Linux testing system
    $commandsToStub = @(
        "$sysDir\dism.exe", "$sysDir\sfc.exe", "$sysDir\ipconfig.exe", "$sysDir\netsh.exe",
        $wingetPath, "$sysDir\usoclient.exe", "$sysDir\chkdsk.exe", 'Optimize-Volume',
        'Import-Module', 'Stop-Service', 'Start-Service', 'Clear-RecycleBin'
    )
    foreach ($cmd in $commandsToStub) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            New-Item -Path "Function:\$cmd" -Value { } -Force | Out-Null
        }
    }

    # Redefine Restart-Computer with Force parameter because Linux pwsh doesn't have it
    Invoke-Expression "function global:Restart-Computer { param([switch]`$Force, [switch]`$Confirm, [switch]`$WhatIf) }"

    if (-not (Get-Command "Get-WindowsUpdate" -ErrorAction SilentlyContinue)) {
        Invoke-Expression "function global:Get-WindowsUpdate { param([switch]`$AcceptAll, [switch]`$Install, [bool]`$AutoReboot) }"
    }
}

Describe "CleanupAndUpdateEverything.ps1" {

    BeforeEach {
        # Mock standard output
        Mock Write-Host {}

        # Mock standard cmdlets used in the script
        Mock Test-Path { return $false }
        Mock Get-ChildItem { return @{ Count = 1 } }
        Mock Remove-Item {}
        Mock Stop-Service {}
        Mock Start-Service {}
        Mock Clear-RecycleBin {}
        Mock Get-Module { return $false } -ParameterFilter { $Name -eq 'PSWindowsUpdate' } # Default to false for PSWindowsUpdate check
        Mock Read-Host { return "N" }
        Mock Restart-Computer {}
        Mock Start-Process {}

        # Mock our stubbed commands
        Mock "$sysDir\dism.exe" {}
        Mock "$sysDir\sfc.exe" {}
        Mock "$sysDir\ipconfig.exe" {}
        Mock "$sysDir\netsh.exe" {}
        Mock "$wingetPath" {}
        Mock "$sysDir\usoclient.exe" {}
        Mock "$sysDir\chkdsk.exe" {}
        Mock Optimize-Volume {}
        Mock Get-WindowsUpdate {}
        Mock Import-Module {}
    }

    It "Should run successfully in SilentMode" {
        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        # Assert
        Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter { $ForegroundColor -eq 'Green' }
        Should -Invoke -CommandName "$sysDir\dism.exe" -Times 2
        Should -Invoke -CommandName "$sysDir\sfc.exe" -Times 1
        Should -Invoke -CommandName "$sysDir\ipconfig.exe" -Times 3
        Should -Invoke -CommandName "$sysDir\netsh.exe" -Times 2
        Should -Invoke -CommandName "$wingetPath" -Times 1
        Should -Invoke -CommandName "$sysDir\usoclient.exe" -Times 3
        Should -Invoke -CommandName Optimize-Volume -Times 1

        # Verify it skips interactive prompts because of SilentMode
        Should -Invoke -CommandName Read-Host -Times 0
    }

    It "Should ask for interactive prompts when not in SilentMode" {
        # Arrange
        Mock Test-Path { return $true } # Make it think reboot is pending
        Mock Read-Host { return "S" }   # Make it answer 'S' to prompts

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1"

        # Assert
        Should -Invoke -CommandName Read-Host -Times 3
        Should -Invoke -CommandName "$sysDir\chkdsk.exe" -Times 1
        Should -Invoke -CommandName Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'ms-windows-store://downloadsandupdates' }
        Should -Invoke -CommandName Restart-Computer -Times 1 -ParameterFilter { $Force -eq $true }
    }

    It "Should not execute conditional commands on negative responses" {
        # Arrange
        Mock Test-Path { return $true } # Make it think reboot is pending
        Mock Read-Host { return "N" }   # Make it answer 'N' to prompts
        Mock chkdsk {}
        Mock Start-Process {}
        Mock Restart-Computer {}

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1"

        # Assert
        Should -Invoke -CommandName Read-Host -Times 3
        Should -Invoke -CommandName chkdsk -Times 0
        Should -Invoke -CommandName Start-Process -Times 0
        Should -Invoke -CommandName Restart-Computer -Times 0
    }

    It "Should NOT perform interactive actions when negative response is provided" {
        # Arrange
        Mock Test-Path { return $true } # Make it think reboot is pending
        Mock Read-Host { return "N" }   # Make it answer 'N' to all prompts

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1"

        # Assert
        Should -Invoke -CommandName Read-Host -Times 3
        Should -Invoke -CommandName chkdsk -Times 0
        Should -Invoke -CommandName Start-Process -Times 0
        Should -Invoke -CommandName Restart-Computer -Times 0
    }

    It "Should handle PSWindowsUpdate logic if module is available" {
        # Arrange
        Mock Get-Module { return $true } -ParameterFilter { $Name -eq 'PSWindowsUpdate' }

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        # Assert
        Should -Invoke -CommandName Import-Module -Times 1 -ParameterFilter { $Name -eq 'PSWindowsUpdate' }
        Should -Invoke -CommandName Get-WindowsUpdate -Times 1 -ParameterFilter { $AcceptAll -eq $true -and $Install -eq $true -and $AutoReboot -eq $false }
        Should -Invoke -CommandName "$sysDir\usoclient.exe" -Times 0
    }

    It "Safe-Remove function should correctly interact with Remove-Item" {
        # Arrange
        Mock Get-ChildItem { return @(1, 2) } # Mock items existing
        Mock Remove-Item {}

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        # Assert
        Should -Invoke -CommandName Remove-Item -ParameterFilter { $ErrorAction -eq 'SilentlyContinue' }
    }
}
