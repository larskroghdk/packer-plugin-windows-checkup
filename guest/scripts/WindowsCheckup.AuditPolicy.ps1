#Requires -Version 5.1

<#
.SYNOPSIS
    Read-only Windows configuration readers derived from windows-harden.

.DESCRIPTION
    Contains no configuration writers.

.EXAMPLE
    . .\WindowsCheckup.AuditPolicy.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

function Get-WindowsCheckupAuditPolicy {
    <#
    .SYNOPSIS
        Exports the advanced audit policy subcategory settings.

    .DESCRIPTION
        Runs auditpol /backup and returns a hashtable that maps each lower-case subcategory GUID (without braces) to its setting: 0 none, 1 success, 2 failure, 3 both.
        The CSV file is deleted afterwards.

    .PARAMETER WorkPath
        A writable directory for the temporary CSV file.

    .EXAMPLE
        $auditPolicy = Get-WindowsCheckupAuditPolicy -WorkPath $workPath

    .OUTPUTS
        System.Collections.Hashtable

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$WorkPath
    )
    $auditpol = Join-Path -Path $env:SystemRoot -ChildPath 'System32\auditpol.exe'
    $csv = Join-Path -Path $WorkPath -ChildPath 'auditpol-backup.csv'
    Remove-Item -LiteralPath $csv -Force -ErrorAction SilentlyContinue
    $result = Invoke-WindowsCheckupNativeCommand -FilePath $auditpol -ArgumentList @('/backup', "/file:$csv")
    if ($result.ExitCode -ne 0) {
        throw "auditpol.exe /backup failed with exit code $($result.ExitCode): $($result.Output)"
    }
    try {
        $header = 'Machine', 'Target', 'Subcategory', 'Guid', 'Inclusion', 'Exclusion', 'Value'
        $rows = Get-Content -LiteralPath $csv | Select-Object -Skip 1 | ConvertFrom-Csv -Header $header
        $policy = @{}
        foreach ($row in $rows) {
            if ([string]::IsNullOrWhiteSpace($row.Guid) -or [string]::IsNullOrWhiteSpace($row.Value)) {
                continue
            }
            $policy[$row.Guid.Trim('{', '}', ' ').ToLowerInvariant()] = [int]$row.Value
        }
        $policy
    }
    finally {
        Remove-Item -LiteralPath $csv -Force -ErrorAction SilentlyContinue
    }
}

function Get-WindowsCheckupAuditSubcategory {
    <#
    .SYNOPSIS
        Reads one audit subcategory setting from an exported audit policy.

    .DESCRIPTION
        Matches the GUID regardless of braces or case.
        A subcategory missing from the export is reported as absent.

    .PARAMETER Policy
        The policy returned by Get-WindowsCheckupAuditPolicy.

    .PARAMETER Guid
        The subcategory GUID.

    .EXAMPLE
        Get-WindowsCheckupAuditSubcategory -Policy $auditPolicy -Guid '0cce923f-69ae-11d9-bed3-505054503030'

    .OUTPUTS
        System.Management.Automation.PSCustomObject with present, type and value.

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Policy,
        [Parameter(Mandatory)]
        [string]$Guid
    )
    $key = $Guid.Trim('{', '}', ' ').ToLowerInvariant()
    if ($Policy.ContainsKey($key)) {
        return [PSCustomObject]@{
            present = $true;
            type    = $null;
            value   = [string]$Policy[$key]
        }
    }
    [PSCustomObject]@{ present = $false; type = $null; value = $null }
}
