BeforeAll {
    $env:windir = "C:\Windows"
    $env:LOCALAPPDATA = "C:\Users\MockUser\AppData\Local"

    # Stub external commands and standard cmdlets that might not exist on the Linux testing system
    $commandsToStub = @(
        "$env:windir\System32\dism.exe", "$env:windir\System32\sfc.exe", "$env:windir\System32\ipconfig.exe",
        "$env:windir\System32\netsh.exe", "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:windir\System32\usoclient.exe", "$env:windir\System32\chkdsk.exe", 'Optimize-Volume',
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
        Mock "$env:windir\System32\dism.exe" {}
        Mock "$env:windir\System32\sfc.exe" {}
        Mock "$env:windir\System32\ipconfig.exe" {}
        Mock "$env:windir\System32\netsh.exe" {}
        Mock "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" {}
        Mock "$env:windir\System32\usoclient.exe" {}
        Mock "$env:windir\System32\chkdsk.exe" {}
        Mock Optimize-Volume {}
        Mock Get-WindowsUpdate {}
        Mock Import-Module {}
    }

    It "Should run successfully in SilentMode" {
        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        # Assert
        Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter { $ForegroundColor -eq 'Green' }
        Should -Invoke -CommandName "$env:windir\System32\dism.exe" -Times 2
        Should -Invoke -CommandName "$env:windir\System32\sfc.exe" -Times 1
        Should -Invoke -CommandName "$env:windir\System32\ipconfig.exe" -Times 3
        Should -Invoke -CommandName "$env:windir\System32\netsh.exe" -Times 2
        Should -Invoke -CommandName "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" -Times 1
        Should -Invoke -CommandName "$env:windir\System32\usoclient.exe" -Times 3
        Should -Invoke -CommandName Optimize-Volume -Times 1

        # Verify it skips interactive prompts because of SilentMode
        Should -Invoke -CommandName Read-Host -Times 0
    }


    It "Should skip interactive commands when Read-Host responses are negative" {
        # Arrange
        Mock Test-Path { return $true } # Make it think reboot is pending
        Mock Read-Host { return "N" }   # Make it answer 'N' to prompts

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1"

        # Assert
        Should -Invoke -CommandName Read-Host -Times 3
        Should -Invoke -CommandName "$env:windir\System32\chkdsk.exe" -Times 0
        Should -Invoke -CommandName Start-Process -Times 0 -ParameterFilter { $FilePath -eq 'ms-windows-store://downloadsandupdates' }
        Should -Invoke -CommandName Restart-Computer -Times 0 -ParameterFilter { $Force -eq $true }
    }

    It "Should ask for interactive prompts when not in SilentMode" {
        # Arrange
        Mock Test-Path { return $true } # Make it think reboot is pending
        Mock Read-Host { return "S" }   # Make it answer 'S' to prompts

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1"

        # Assert
        Should -Invoke -CommandName Read-Host -Times 3
        Should -Invoke -CommandName "$env:windir\System32\chkdsk.exe" -Times 1
        Should -Invoke -CommandName Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'ms-windows-store://downloadsandupdates' }
        Should -Invoke -CommandName Restart-Computer -Times 1 -ParameterFilter { $Force -eq $true }
    }

    It "Should handle PSWindowsUpdate logic if module is available" {
        # Arrange
        Mock Get-Module { return $true } -ParameterFilter { $Name -eq 'PSWindowsUpdate' }

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        # Assert
        Should -Invoke -CommandName Import-Module -Times 1 -ParameterFilter { $Name -eq 'PSWindowsUpdate' }
        Should -Invoke -CommandName Get-WindowsUpdate -Times 1 -ParameterFilter { $AcceptAll -eq $true -and $Install -eq $true -and $AutoReboot -eq $false }
        Should -Invoke -CommandName "$env:windir\System32\usoclient.exe" -Times 0
    }

    It "Safe-Remove function should correctly interact with Remove-Item" {
        # Arrange
        Mock Remove-Item {}

        # Act
        . "$PSScriptRoot/CleanupAndUpdateEverything.ps1" -SilentMode

        # Assert
        Should -Invoke -CommandName Remove-Item
    }
}
