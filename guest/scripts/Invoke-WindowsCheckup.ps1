#Requires -Version 5.1

<#
.SYNOPSIS
     Reads Windows facts and baseline configuration without changing security settings.

.DESCRIPTION
    Requires an elevated Windows PowerShell session. Writes only temporary exports and JSON.

.PARAMETER Action
    Detect or Inspect.

.PARAMETER InputPath
    Baseline settings JSON.

.PARAMETER OutputPath
    Output JSON file in the isolated working directory.

.EXAMPLE
    .\Invoke-WindowsCheckup.ps1 -Action Detect -OutputPath C:\Windows\Temp\facts.json

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'Detect',
        'Inspect'
    )]
    [string]$Action,
    [string]$InputPath,
    [Parameter(Mandatory)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

foreach ($part in 'NativeCommand', 'Registry', 'SecurityPolicy', 'AuditPolicy', 'Services') {
    . (Join-Path $PSScriptRoot "WindowsCheckup.$part.ps1")
}
. (Join-Path $PSScriptRoot 'Inspect.ps1')

$workDirectory = Split-Path -Parent $OutputPath

try {
    if ($Action -eq 'Detect') {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'An elevated session is required'
        }
        if (-not [Environment]::Is64BitProcess) {
            throw '64-bit Windows PowerShell is required'
        }
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem
        $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $result = @{
            computerName = $env:COMPUTERNAME;
            os           = @{
                caption          = $os.Caption;
                product_name     = $os.Caption;
                edition_id       = $key.EditionID
                major            = ([version]$os.Version).Major;
                minor            = ([version]$os.Version).Minor;
                build            = [int]$os.BuildNumber;
                product_type     = [int]$os.ProductType;
                architecture     = $os.OSArchitecture;
                is_64bit_process = [Environment]::Is64BitProcess;
            };
            domain       = @{
                part_of_domain = [bool]$computer.PartOfDomain;
            }
        }
    }
    else {
        $settings = @([IO.File]::ReadAllText($InputPath, [Text.Encoding]::UTF8) | ConvertFrom-Json)
        $result = @{
            items = @(Invoke-WindowsCheckupInspect -Settings $settings -WorkPath $workDirectory)
        }
    }
    [IO.File]::WriteAllText($OutputPath, (ConvertTo-Json -InputObject $result -Depth 12 -Compress), (New-Object Text.UTF8Encoding($false)))
}
catch {
    [Console]::Error.WriteLine('Windows checkup action failed; inspect elevation and reader availability.')
    exit 1
}
