#Requires -Version 5.1

<#
.SYNOPSIS
    Pester tests for WindowsCheckup.Inspect.ps1.

.DESCRIPTION
    Mocks the registry root and the policy exports, so no host security policy is read or changed.

.EXAMPLE
    Invoke-Pester -Path test/pester/Inspect.Tests.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

BeforeAll {
    $root = Join-Path $PSScriptRoot '../../guest/scripts'
    . (Join-Path $root 'WindowsCheckup.Registry.ps1')
    . (Join-Path $root 'WindowsCheckup.SecurityPolicy.ps1')
    . (Join-Path $root 'WindowsCheckup.AuditPolicy.ps1')
    . (Join-Path $root 'WindowsCheckup.Inspect.ps1')
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
