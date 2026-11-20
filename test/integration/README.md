# 🧪 Live validation

Use a disposable Windows guest with an elevated WinRM account. No live guest or credentials are included in this repository.

Build and install the binary, then run the null-builder example with `PKR_VAR_winrm_host`, `PKR_VAR_winrm_username`, and `PKR_VAR_winrm_password` in the environment:

```powershell
go build -ldflags '-X main.versionPrerelease=' -o bin/packer-plugin-windows-checkup.exe .
packer plugins install --path bin/packer-plugin-windows-checkup.exe github.com/larskroghdk/windows-checkup
packer validate examples/local
packer build examples/local
```

Inspect `reports/windows-checkup.json`. Independently compare sampled registry values with 64-bit Registry Editor, user rights with a security-policy export, audit GUIDs with `auditpol /get`, and service startup with `Get-CimInstance Win32_Service`. Run on both domain profiles where available. Repeat after applying windows-harden and review deferred WinRM-sensitive policies as legitimate noncompliance.

The unit tests exercise protocol fixtures and all catalog entries. They do not demonstrate successful validation of a live Windows guest.

An automated opt-in test can also run **inside an elevated disposable Windows guest** with Go available:

```powershell
$env:WINDOWS_CHECKUP_LIVE = '1'
go test -tags integration ./test/integration -v
```

It executes the actual Detect and Inspect scripts, evaluates every selected baseline control, and cross-checks a readable registry DWORD against a separate `reg.exe` query. It does not require the guest to be compliant. Without the environment opt-in it skips, and it is excluded from normal unit runs. It does not replace a full live Packer/WinRM build.
