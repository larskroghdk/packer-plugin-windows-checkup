#Requires -Version 5.1

<#
.SYNOPSIS
    Tests read-only policy parsing without reading or changing host security policy.

.DESCRIPTION
    Uses exported policy fixtures and an isolated PowerShell environment.

.EXAMPLE
    Invoke-Pester test/pester

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

BeforeAll {
    $root = Join-Path $PSScriptRoot '../../guest/scripts'
    . (Join-Path $root 'WindowsCheckup.Registry.ps1')
    . (Join-Path $root 'WindowsCheckup.SecurityPolicy.ps1')
    . (Join-Path $root 'WindowsCheckup.AuditPolicy.ps1')
    . (Join-Path $root 'Inspect.ps1')
}

Describe 'Inspection working directory' {
    BeforeEach {
        Mock Get-WindowsCheckupRegistryRoot {
            $root = [PSCustomObject]@{}
            $root | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
            $root
        }
        Mock Export-WindowsCheckupSecurityPolicy {
            @{
                'System Access' = @{
                    MinimumPasswordLength = '14'
                }
            }
        }
    }
    It 'Passes the explicit directory to the policy export' {
        $setting = [PSCustomObject]@{
            id             = 'account_policy:MinimumPasswordLength';
            kind           = 'account_policy';
            account_policy = @{
                name = 'MinimumPasswordLength'
            }
        }
        $result = @(Invoke-WindowsCheckupInspect -Settings @($setting) -WorkPath 'C:\audit-fixture')
        $result.Count | Should -Be 1
        $result[0].value | Should -Be '14'
        Should -Invoke Export-WindowsCheckupSecurityPolicy -Times 1 -Exactly -ParameterFilter { $WorkPath -eq 'C:\audit-fixture' }
    }
    It 'Reports failed exports without stopping another reader' {
        Mock Export-WindowsCheckupSecurityPolicy {
            throw 'fixture failure'
        }
        Mock Get-WindowsCheckupAuditPolicy {
            @{
                '0cce923f-69ae-11d9-bed3-505054503030' = 3
            }
        }
        $settings = @(
            [PSCustomObject]@{
                id             = 'account_policy:MinimumPasswordLength';
                kind           = 'account_policy';
                account_policy = @{
                    name = 'MinimumPasswordLength'
                }
            }
            [PSCustomObject]@{
                id           = 'audit_policy:fixture';
                kind         = 'audit_policy';
                audit_policy = @{
                    subcategory_guid = '0cce923f-69ae-11d9-bed3-505054503030'
                }
            }
        )
        $result = @(Invoke-WindowsCheckupInspect -Settings $settings -WorkPath 'C:\audit-fixture')
        $result.Count | Should -Be 2
        $result[0].error | Should -Be 'fixture failure'
        $result[1].error | Should -BeNullOrEmpty
        $result[1].value | Should -Be '3'
    }
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
    It 'Preserves unsigned DWORD bit patterns' {
        (ConvertTo-WindowsCheckupUInt32 -Value -1) | Should -Be 4294967295
    }
    It 'Matches audit subcategories without depending on localized names' {
        $policy = @{'0cce923f-69ae-11d9-bed3-505054503030' = 3 }
        (Get-WindowsCheckupAuditSubcategory -Policy $policy -Guid '{0CCE923F-69AE-11D9-BED3-505054503030}').value | Should -Be '3'
        (Get-WindowsCheckupAuditSubcategory -Policy $policy -Guid 'missing').present | Should -BeFalse
    }
}
