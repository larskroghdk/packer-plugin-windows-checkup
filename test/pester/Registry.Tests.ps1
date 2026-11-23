#Requires -Version 5.1

<#
.SYNOPSIS
    Pester tests for WindowsCheckup.Registry.ps1.

.DESCRIPTION
    Covers DWORD conversion without reading the host registry.

.EXAMPLE
    Invoke-Pester -Path test/pester/Registry.Tests.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

BeforeAll {
    $root = Join-Path $PSScriptRoot '../../guest/scripts'
    . (Join-Path $root 'WindowsCheckup.Registry.ps1')
}

Describe 'Registry readers' {
    It 'Preserves unsigned DWORD bit patterns' {
        (ConvertTo-WindowsCheckupUInt32 -Value -1) | Should -Be 4294967295
    }
}
