#Requires -Version 5.1

<#
.SYNOPSIS
    Parses and statically analyzes all packaged guest scripts.

.DESCRIPTION
    Does not execute guest security readers on the development machine.

.EXAMPLE
    pwsh -NoProfile -File scripts/check-powershell.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

$ErrorActionPreference = 'Stop'

$files = Get-ChildItem (Join-Path $PSScriptRoot '../guest/scripts') -Filter '*.ps1'
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw ($parseErrors | Out-String)
    }
}

Import-Module PSScriptAnalyzer -RequiredVersion 1.22.0

$issues = @($files | ForEach-Object {
        Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error
    }
)
if ($issues.Count -gt 0) {
    throw ($issues | Out-String)
}
Write-Output "Parsed and analyzed $($files.Count) guest scripts."
