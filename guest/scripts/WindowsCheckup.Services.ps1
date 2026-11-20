#Requires -Version 5.1

<#
.SYNOPSIS
    Read-only Windows configuration readers derived from windows-harden.

.DESCRIPTION
    Contains no configuration writers.

.EXAMPLE
    . .\WindowsCheckup.Services.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

function Get-WindowsCheckupServiceStartType {
    <#
    .SYNOPSIS
        Reads a service's start type from the registry.

    .DESCRIPTION
        Reads the Start value under SYSTEM\CurrentControlSet\Services.
        A service that is not installed is reported as absent, which the plugin treats as not applicable.

    .PARAMETER Root
        The open root key, normally from Get-WindowsCheckupRegistryRoot.

    .PARAMETER Name
        The service name (not the display name).

    .EXAMPLE
        Get-WindowsCheckupServiceStartType -Root $root -Name 'XblGameSave'

    .OUTPUTS
        System.Management.Automation.PSCustomObject with present, type and value.

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryKey]$Root,
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_.\-]+$')]
        [string]$Name
    )
    $path = "SYSTEM\CurrentControlSet\Services\$Name"
    $key = $Root.OpenSubKey($path, $false)
    if ($null -eq $key) {
        return [PSCustomObject]@{ present = $false; type = $null; value = $null }
    }
    $key.Dispose()
    $state = Get-WindowsCheckupRegistryValue -Root $Root -Path $path -Name 'Start'
    if (-not $state.present) { throw 'Installed service has no startup configuration' }
    if ($state.type -ne 'REG_DWORD') { throw 'Service startup configuration is not a DWORD' }
    $state
}
