#Requires -Version 5.1

<#
.SYNOPSIS
    Pester tests for WindowsCheckup.AuditPolicy.ps1.

.DESCRIPTION
    Matches audit policy fixtures without running auditpol on the host.

.EXAMPLE
    Invoke-Pester -Path test/pester/AuditPolicy.Tests.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

BeforeAll {
    $root = Join-Path $PSScriptRoot '../../guest/scripts'
    . (Join-Path $root 'WindowsCheckup.AuditPolicy.ps1')
}

Describe 'Audit policy readers' {
    It 'Matches audit subcategories without depending on localized names' {
        $policy = @{'0cce923f-69ae-11d9-bed3-505054503030' = 3 }
        (Get-WindowsCheckupAuditSubcategory -Policy $policy -Guid '{0CCE923F-69AE-11D9-BED3-505054503030}').value | Should -Be '3'
        (Get-WindowsCheckupAuditSubcategory -Policy $policy -Guid 'missing').present | Should -BeFalse
    }
}
