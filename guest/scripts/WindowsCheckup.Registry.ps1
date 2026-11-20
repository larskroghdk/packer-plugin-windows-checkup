#Requires -Version 5.1

<#
.SYNOPSIS
    Read-only Windows configuration readers derived from windows-harden.

.DESCRIPTION
    Contains no configuration writers.

.EXAMPLE
    . .\WindowsCheckup.Registry.ps1

.NOTES
    Author: Lars Krogh
    Version: 0.1.0
#>

function Get-WindowsCheckupRegistryRoot {
    <#
    .SYNOPSIS
        Opens the 64-bit view of HKEY_LOCAL_MACHINE.

    .DESCRIPTION
        Returns HKLM opened with RegistryView.Registry64, so reads and writes never land in the WOW6432Node redirected view.
        The caller must dispose the key.

    .EXAMPLE
        $root = Get-WindowsCheckupRegistryRoot
        try { Get-WindowsCheckupRegistryValue -Root $root -Path 'SOFTWARE\Policies' -Name 'Example' } finally { $root.Dispose() }

    .OUTPUTS
        Microsoft.Win32.RegistryKey

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Win32.RegistryKey])]
    param()
    [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
}

function ConvertTo-WindowsCheckupUInt32 {
    <#
    .SYNOPSIS
        Reinterprets a signed 32-bit registry DWORD as unsigned.

    .DESCRIPTION
        RegistryKey.GetValue returns REG_DWORD data as Int32, so values above 2147483647 come back negative.
        This keeps the bit pattern and returns the unsigned value that the baseline uses.

    .PARAMETER Value
        The Int32 value read from the registry.

    .EXAMPLE
        ConvertTo-WindowsCheckupUInt32 -Value -1

    .OUTPUTS
        System.UInt32

    .NOTES
        Author  : Lars Krogh
        Version : 1.0.0
    #>
    [CmdletBinding()]
    [OutputType([uint32])]
    param(
        [Parameter(Mandatory)]
        [int32]$Value
    )
    [BitConverter]::ToUInt32([BitConverter]::GetBytes($Value), 0)
}

function Get-WindowsCheckupRegistryValue {
    <#
    .SYNOPSIS
        Reads one registry value below a root key.

    .DESCRIPTION
        Returns present = $false when the key or the value does not exist.
        Otherwise returns the registry type name (REG_DWORD, REG_SZ, ...) and the data as a string.
        DWORDs are returned as unsigned decimal, and environment variables are not expanded.

    .PARAMETER Root
        The open root key, normally from Get-WindowsCheckupRegistryRoot.

    .PARAMETER Path
        The subkey path below the root, without a hive prefix.

    .PARAMETER Name
        The value name. An empty string reads the key's default value.

    .EXAMPLE
        Get-WindowsCheckupRegistryValue -Root $root -Path 'SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LmCompatibilityLevel'

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
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )
    $absent = [PSCustomObject]@{ present = $false; type = $null; value = $null }
    $key = $Root.OpenSubKey($Path, $false)
    if ($null -eq $key) {
        return $absent
    }
    try {
        if ($key.GetValueNames() -notcontains $Name) {
            return $absent
        }
        $kind = $key.GetValueKind($Name)
        $raw = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        switch ($kind) {
            ([Microsoft.Win32.RegistryValueKind]::DWord) {
                $type = 'REG_DWORD'
                $value = [string](ConvertTo-WindowsCheckupUInt32 -Value $raw)
            }
            ([Microsoft.Win32.RegistryValueKind]::String) {
                $type = 'REG_SZ'
                $value = [string]$raw
            }
            ([Microsoft.Win32.RegistryValueKind]::ExpandString) {
                $type = 'REG_EXPAND_SZ'
                $value = [string]$raw
            }
            default {
                $type = "REG_$($kind.ToString().ToUpperInvariant())"
                $value = ($raw | ForEach-Object { [string]$_ }) -join ','
            }
        }
        [PSCustomObject]@{ present = $true; type = $type; value = $value }
    }
    finally {
        $key.Dispose()
    }
}
