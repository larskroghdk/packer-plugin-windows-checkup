#Requires -Version 5.1

<#
.SYNOPSIS
    Runs PowerShell fixture tests without creating registry fixtures.

.DESCRIPTION
    Disables Pester's TestRegistry because these tests use no writable registry state.

.EXAMPLE
    pwsh -NoProfile -File scripts/test-powershell.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

$ErrorActionPreference = 'Stop'

Import-Module Pester -RequiredVersion 5.6.1

$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path $PSScriptRoot '../test/pester'
$configuration.Run.Exit = $true
$configuration.TestRegistry.Enabled = $false

Invoke-Pester -Configuration $configuration
