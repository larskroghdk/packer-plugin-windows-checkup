---
name: powershell-development
description: Implement or debug the embedded read-only guest PowerShell (Detect and Inspect readers) and its Pester tests, especially JSON contracts, registry reads, security and audit policy exports and service inspection. Use for guest-script changes; PowerShell 7 alone is not a supported guest test.
---

# PowerShell development

Read [AGENTS.md](../../../AGENTS.md) (PowerShell section) and [INVARIANTS.md](../../../INVARIANTS.md). The guest runs elevated, 64-bit Windows PowerShell 5.1; host-side `pwsh` analysis does not change that runtime. Keep comparison and policy decisions in Go.

## Stay read-only

The scripts expose only `Detect` and `Inspect`. They never write security settings, apply policy, change service configuration, schedule tasks or reboot. `TestScriptsAreReadOnly` in [guest_test.go](../../../guest/guest_test.go) guards this; extend it rather than weaken it when a script part is added.

## Work at the guest boundary

1. Locate the action in [Invoke-WindowsCheckup.ps1](../../../guest/scripts/Invoke-WindowsCheckup.ps1), its dot-sourced `WindowsCheckup.*.ps1` part, and the Go `json` tags in `internal/facts` or `internal/audit` that consume it. Inspect both sides before changing a field.
2. Keep structured objects on the success pipeline. Formatting cmdlets or incidental method return values must not contaminate the JSON.
3. For collection fields, test absent, empty, singleton and multiple results crossing the wire. Distinguish an absent value, an empty array, an empty string and a failed read; do not infer one from another. Account for the 5.1 `ConvertFrom-Json` enumeration and strict-mode property access.
4. Use the native-command wrapper for `secedit` and `auditpol`. Temporary exports go in the working directory and are removed afterwards. Check exit codes rather than assuming `$ErrorActionPreference` classifies native-process failures.
5. Read HKLM through the 64-bit registry view, dispose registry handles in `finally`, and compare identities by SID so localized installations work. Represent reader exceptions without raw sensitive data, and never collect credentials, tokens or session identity.

A new script part needs an entry in the loader and must stay embedded by `guest/guest.go`. Follow the I19 help requirements rather than adding inline commentary.

## Validate in the intended runtime

Run [test/pester](../../../test/pester) under `powershell.exe` 5.1 with Pester 5.6.1 (`make test-ps`) and PSScriptAnalyzer 1.22.0 (`make pslint`). Normal tests never audit or change the development host's policy.

For real reads, use the opt-in [live validation](../../../test/integration/README.md) on an authorized disposable guest. A `pwsh` pass, a mocked reader or a parser test does not establish live behavior; report it separately.
