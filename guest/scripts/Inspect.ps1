#Requires -Version 5.1

<#
.SYNOPSIS
    Reads every requested baseline control and isolates individual failures.

.DESCRIPTION
    Dot-sourced by the read-only checkup entry point.

.EXAMPLE
    . .\Inspect.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

function Invoke-WindowsCheckupInspect {
    <#
    .SYNOPSIS
        Reads the current state of each baseline setting.

    .DESCRIPTION
        Returns one state object per setting, in input order.
        Security policy and audit policy are exported once and shared by every setting of those kinds.
        When an export fails, each affected setting reports that failure in its error field.
        A failure on one setting never stops the others.

    .PARAMETER Settings
        Baseline settings as sent by the plugin, each with an id, a kind and the payload for that kind.

    .PARAMETER WorkPath
        Isolated guest directory for read-only policy exports.

    .EXAMPLE
        Invoke-WindowsCheckupInspect -Settings $settings -WorkPath $directory

    .OUTPUTS
        System.Management.Automation.PSCustomObject with id, present, type, value and error.

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$Settings,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkPath
    )
    $root = Get-WindowsCheckupRegistryRoot
    $kinds = @($Settings | ForEach-Object { $_.kind } | Sort-Object -Unique)
    $securityPolicy = $null
    $auditPolicy = $null
    $exportFailure = @{}
    if ($kinds -contains 'user_right' -or $kinds -contains 'account_policy') {
        try {
            $securityPolicy = Export-WindowsCheckupSecurityPolicy -WorkPath $WorkPath
        }
        catch {
            $exportFailure['user_right'] = $_.Exception.Message
            $exportFailure['account_policy'] = $_.Exception.Message
        }
    }
    if ($kinds -contains 'audit_policy') {
        try {
            $auditPolicy = Get-WindowsCheckupAuditPolicy -WorkPath $WorkPath
        }
        catch {
            $exportFailure['audit_policy'] = $_.Exception.Message
        }
    }
    try {
        foreach ($setting in $Settings) {
            $state = $null
            $failure = $null
            try {
                if ($exportFailure.ContainsKey($setting.kind)) {
                    throw $exportFailure[$setting.kind]
                }
                switch ($setting.kind) {
                    'registry' {
                        $state = Get-WindowsCheckupRegistryValue -Root $root -Path $setting.registry.path -Name $setting.registry.name
                    }
                    'user_right' {
                        $state = Get-WindowsCheckupUserRight -Policy $securityPolicy -Right $setting.user_right.right
                    }
                    'account_policy' {
                        $state = Get-WindowsCheckupAccountPolicy -Policy $securityPolicy -Name $setting.account_policy.name
                    }
                    'audit_policy' {
                        $state = Get-WindowsCheckupAuditSubcategory -Policy $auditPolicy -Guid $setting.audit_policy.subcategory_guid
                    }
                    'service' {
                        $state = Get-WindowsCheckupServiceStartType -Root $root -Name $setting.service.name
                    }
                    default {
                        throw "Unsupported setting kind '$($setting.kind)'"
                    }
                }
            }
            catch {
                $failure = $_.Exception.Message
            }
            [PSCustomObject]@{
                id      = $setting.id
                present = if ($null -ne $state) { $state.present } else { $false }
                type    = if ($null -ne $state) { $state.type } else { $null }
                value   = if ($null -ne $state) { $state.value } else { $null }
                error   = $failure
            }
        }
    }
    finally {
        $root.Dispose()
    }
}
