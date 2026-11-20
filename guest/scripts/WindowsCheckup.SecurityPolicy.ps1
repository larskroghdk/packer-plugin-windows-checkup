#Requires -Version 5.1

<#
.SYNOPSIS
    Read-only Windows configuration readers derived from windows-harden.

.DESCRIPTION
    Contains no configuration writers.

.EXAMPLE
    . .\WindowsCheckup.SecurityPolicy.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

function ConvertFrom-WindowsCheckupSecurityTemplate {
    <#
    .SYNOPSIS
        Parses a secedit security template into sections of key/value pairs.

    .DESCRIPTION
        Returns a hashtable keyed by section name.
        Each section is a case-insensitive hashtable of its entries.
        Blank lines, ';' comments, entries before the first section and lines without a key are ignored.

    .PARAMETER Text
        The template text, already decoded from UTF-16.

    .EXAMPLE
        ConvertFrom-WindowsCheckupSecurityTemplate -Text ([IO.File]::ReadAllText($path, [Text.Encoding]::Unicode))

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
        [AllowEmptyString()]
        [string]$Text
    )
    $sections = @{}
    $current = $null
    foreach ($line in ($Text -split '\r?\n')) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith(';')) {
            continue
        }
        if ($trimmed -match '^\[(.+)\]$') {
            $current = New-Object System.Collections.Hashtable ([StringComparer]::OrdinalIgnoreCase)
            $sections[$Matches[1]] = $current
            continue
        }
        if ($null -eq $current) {
            continue
        }
        $index = $trimmed.IndexOf('=')
        if ($index -lt 1) {
            continue
        }
        $current[$trimmed.Substring(0, $index).Trim()] = $trimmed.Substring($index + 1).Trim()
    }
    $sections
}

function ConvertTo-WindowsCheckupSidList {
    <#
    .SYNOPSIS
        Normalizes a user-right assignment to a sorted list of SIDs.

    .DESCRIPTION
        Accepts the comma-separated principals from a security template.
        Entries prefixed with '*' are SIDs.
        Other entries are account names, which are translated to SIDs and kept as-is if they cannot be resolved.
        Returns upper-case SIDs, sorted and de-duplicated, joined with commas.

    .PARAMETER Value
        The assignment string, for example '*S-1-5-32-544,*S-1-5-11'.

    .EXAMPLE
        ConvertTo-WindowsCheckupSidList -Value '*S-1-5-32-555,*S-1-5-32-544'

    .OUTPUTS
        System.String

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )
    $sids = foreach ($item in ($Value -split ',')) {
        $principal = $item.Trim()
        if ($principal -eq '') {
            continue
        }
        if ($principal.StartsWith('*')) {
            $principal.Substring(1).ToUpperInvariant()
            continue
        }
        try {
            $account = New-Object System.Security.Principal.NTAccount ($principal)
            $account.Translate([System.Security.Principal.SecurityIdentifier]).Value.ToUpperInvariant()
        }
        catch [System.Security.Principal.IdentityNotMappedException] {
            $principal
        }
    }
    (@($sids) | Sort-Object -Unique) -join ','
}

function Invoke-WindowsCheckupSecedit {
    <#
    .SYNOPSIS
        Runs secedit.exe quietly and checks its exit code.

    .DESCRIPTION
        Adds /log and /quiet to the arguments. Any non-zero code, including warnings, fails the audit reader so an incomplete export cannot prove compliance.

    .PARAMETER ArgumentList
        The secedit arguments, starting with the operation (/export or /configure).

    .PARAMETER LogPath
        Where secedit writes its log.

    .EXAMPLE
        Invoke-WindowsCheckupSecedit -ArgumentList @('/export', '/cfg', $templatePath, '/areas', 'USER_RIGHTS') -LogPath $logPath

    .OUTPUTS
        System.Int32

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory)]
        [string]$LogPath
    )
    $secedit = Join-Path -Path $env:SystemRoot -ChildPath 'System32\secedit.exe'
    $result = Invoke-WindowsCheckupNativeCommand -FilePath $secedit -ArgumentList ($ArgumentList + @('/log', $LogPath, '/quiet'))
    if ($result.ExitCode -ne 0) {
        $tail = ''
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $tail = (Get-Content -LiteralPath $LogPath -Tail 20) -join ' | '
        }
        throw "secedit.exe $($ArgumentList[0]) failed with exit code $($result.ExitCode). Output: $($result.Output) Log: $tail"
    }
    $result.ExitCode
}

function Export-WindowsCheckupSecurityPolicy {
    <#
    .SYNOPSIS
        Exports the local security policy and user rights.

    .DESCRIPTION
        Runs secedit /export for the SECURITYPOLICY and USER_RIGHTS areas, parses the template and deletes the exported file.

    .PARAMETER WorkPath
        A writable directory for the exported template and the secedit log.

    .EXAMPLE
        $policy = Export-WindowsCheckupSecurityPolicy -WorkPath $workPath

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
    $templatePath = Join-Path -Path $WorkPath -ChildPath 'secedit-export.inf'
    $logPath = Join-Path -Path $WorkPath -ChildPath 'secedit-export.log'
    $null = Invoke-WindowsCheckupSecedit -ArgumentList @('/export', '/cfg', $templatePath, '/areas', 'SECURITYPOLICY', 'USER_RIGHTS') -LogPath $logPath
    try {
        ConvertFrom-WindowsCheckupSecurityTemplate -Text ([IO.File]::ReadAllText($templatePath, [Text.Encoding]::Unicode))
    }
    finally {
        Remove-Item -LiteralPath $templatePath -Force -ErrorAction SilentlyContinue
    }
}

function Get-WindowsCheckupUserRight {
    <#
    .SYNOPSIS
        Reads who holds a user right in an exported security policy.

    .DESCRIPTION
        A right that does not appear in the export is assigned to no one.
        It is reported as present with an empty value, not as absent.

    .PARAMETER Policy
        The policy returned by Export-WindowsCheckupSecurityPolicy.

    .PARAMETER Right
        The privilege or logon right constant, for example SeNetworkLogonRight.

    .EXAMPLE
        Get-WindowsCheckupUserRight -Policy $policy -Right 'SeDenyNetworkLogonRight'

    .OUTPUTS
        System.Management.Automation.PSCustomObject with present, type and value.

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Policy,
        [Parameter(Mandatory)]
        [string]$Right
    )
    $value = ''
    if ($Policy.ContainsKey('Privilege Rights') -and $Policy['Privilege Rights'].ContainsKey($Right)) {
        $value = $Policy['Privilege Rights'][$Right]
    }
    [PSCustomObject]@{ present = $true; type = $null; value = (ConvertTo-WindowsCheckupSidList -Value $value) }
}

function Get-WindowsCheckupAccountPolicy {
    <#
    .SYNOPSIS
        Reads an account policy value from an exported security policy.

    .DESCRIPTION
        Looks the name up in the [System Access] section.
        A name that is not exported is reported as absent.

    .PARAMETER Policy
        The policy returned by Export-WindowsCheckupSecurityPolicy.

    .PARAMETER Name
        The [System Access] key, for example MinimumPasswordLength.

    .EXAMPLE
        Get-WindowsCheckupAccountPolicy -Policy $policy -Name 'LockoutBadCount'

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
        [string]$Name
    )
    if ($Policy.ContainsKey('System Access') -and $Policy['System Access'].ContainsKey($Name)) {
        return [PSCustomObject]@{ present = $true; type = $null; value = [string]$Policy['System Access'][$Name] }
    }
    [PSCustomObject]@{ present = $false; type = $null; value = $null }
}
