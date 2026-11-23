#Requires -Version 5.1

<#
.SYNOPSIS
    Pester tests for WindowsCheckup.SecurityPolicy.ps1.

.DESCRIPTION
    Parses exported security template fixtures without reading or changing host security policy.

.EXAMPLE
    Invoke-Pester -Path test/pester/SecurityPolicy.Tests.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

BeforeAll {
    $root = Join-Path $PSScriptRoot '../../guest/scripts'
    . (Join-Path $root 'WindowsCheckup.SecurityPolicy.ps1')
}

Describe 'Security policy readers' {
    It 'Parses account policy values and unordered SID assignments' {
        $policy = ConvertFrom-WindowsCheckupSecurityTemplate -Text "[System Access]`r`nMinimumPasswordLength = 14`r`n[Privilege Rights]`r`nSeNetworkLogonRight = *S-1-5-32-544,*S-1-5-11,*S-1-5-11"
        (Get-WindowsCheckupAccountPolicy -Policy $policy -Name MinimumPasswordLength).value | Should -Be '14'
        (Get-WindowsCheckupUserRight -Policy $policy -Right SeNetworkLogonRight).value | Should -Be 'S-1-5-11,S-1-5-32-544'
    }
    It 'Distinguishes a missing account policy from an empty user right' {
        $policy = ConvertFrom-WindowsCheckupSecurityTemplate -Text '[System Access]'
        (Get-WindowsCheckupAccountPolicy -Policy $policy -Name Missing).present | Should -BeFalse
        $right = Get-WindowsCheckupUserRight -Policy $policy -Right SeBackupPrivilege
        $right.present | Should -BeTrue
        $right.value | Should -Be ''
    }
}
