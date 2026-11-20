# 🛡️ packer-plugin-windows-checkup

A native HashiCorp Packer provisioner that independently audits the Windows policies implemented by [windows-harden](https://github.com/larskroghdk/packer-plugin-windows-harden). It reads actual configuration over WinRM and writes a structured JSON report on the Packer host. It never applies security policy, restarts services, changes firewall rules, or reboots Windows.

Author: Lars Krogh. Plugin version: 0.1.0 (development). License: MPL-2.0.

## 🖥️ Baseline and supported systems

The six baseline files are an exact snapshot of windows-harden commit `8dc70d2c81be4515ad243dfbe288d61151ab722d`, including its non-domain-joined overrides and Microsoft package provenance. See the [complete inventory](docs/control-inventory.md), [hash manifest](internal/baseline/data-manifest.json), and [baseline maintenance contract](docs/baseline-contract.md).

| System | Build | Baseline |
| --- | ---: | --- |
| Windows Server 2019 member server | 17763 | ws2019-member |
| Windows Server 2022 | 20348 | ws2022 |
| Windows Server 2025 | 26100 | ws2025-2602 |
| Windows 11 24H2 | 26100 | win11-24h2 |
| Windows 11 25H2 | 26200 | win11-25h2 |
| Windows 11 26H2 | 26300 | win11-26h2 |

Selection follows the source's lifecycle table and edition restrictions at execution time. For example, Windows 11 24H2 consumer editions are already out of support on 2026-11-20; Enterprise/Education remain eligible until their pinned support date. Domain controllers and Windows client LTSC editions are excluded. Server 2016 and Windows 10 have lifecycle entries but no implemented baseline. Unsupported systems produce an execution error and no claimed compliance.

The audit verifies exactly what the hardening plugin configures: registry values and types, local account policies, SID assignments, advanced audit subcategories, and service startup types. Defender, firewall, SMB, TLS, and authentication policies are covered where present in those definitions. The source does not implement independent optional-feature, firewall-rule, service-running-state, or runtime Defender health requirements. Stored policy compliance does not establish effective runtime health or prove that domain policy will not override it later. Registry absence is compliant only for an explicit `ABSENT` requirement. An absent service is `NotApplicable` after the reader verifies the service key is absent.

## 🚀 Installation and use

Requires Go 1.26.10, Packer with plugin protocol x5 support, and an elevated 64-bit Windows PowerShell 5.1 WinRM session on the guest. Build locally before the first release is published:

```powershell
go build -ldflags '-X main.versionPrerelease=' -o bin/packer-plugin-windows-checkup.exe .
packer plugins install --path bin/packer-plugin-windows-checkup.exe github.com/larskroghdk/windows-checkup
```

After a versioned release is published, `packer init` can install it using:

```hcl
packer {
  required_plugins {
    windows-checkup = {
      source  = "github.com/larskroghdk/windows-checkup"
      version = ">= 0.1.0"
    }
  }
}

build {
  sources = ["source.hyperv-iso.windows"]
  provisioner "windows-checkup" {
    report_path                   = "reports/windows-checkup.json"
    report_format                 = "json"
    fail_on_noncompliance          = false
    fail_on_error                 = false
    minimum_compliance_percentage = 0
    severity_threshold            = "Low"
  }
}
```

The builder must be defined separately. A complete [null-builder example](examples/local/windows-checkup.pkr.hcl) audits an existing VM. Checkup can run after windows-harden or independently. Baseline selection and domain profile detection are automatic; there is no dependency on hardening output, logs, or installed binaries.

## ⚙️ Configuration and enforcement

| Option | Default | Meaning |
| --- | --- | --- |
| `report_path` | `reports/windows-checkup.json` | Host path, relative to Packer's working directory or absolute |
| `report_format` | `json` | Only JSON is accepted |
| `fail_on_noncompliance` | `false` | Fail on `NonCompliant` or `NotConfigured` at or above the severity threshold |
| `fail_on_error` | `false` | Fail on control errors or execution failures, including unsupported OS |
| `minimum_compliance_percentage` | `0` | Enforce a percentage from 0 through 100; zero disables this check |
| `severity_threshold` | `Low` | `Low`, `Medium`, `High`, or `Critical`; filters only noncompliance enforcement |

The source provides no severity ratings, so every imported control is conservatively labeled **Medium**, as an explicit project convention rather than an upstream rating. Setting `severity_threshold = "High"` therefore excludes all current controls from noncompliance enforcement. Percentage enforcement is independent of severity. Set `fail_on_error = true` for strict builds: errors are excluded from the percentage denominator and must be enforced separately.

The percentage is `100 × Compliant / (Compliant + NonCompliant + NotConfigured)`. No evaluated controls yields 0%, and fails any positive minimum. `NotApplicable` and `Error` never count as compliant. Audit-only execution failures are recorded and allow the build to continue. Cancellation and host-report write failures always return an error. Use distinct report paths for concurrent builds.

## 📊 Report

See the versioned [JSON schema](docs/report.schema.json) and [illustrative sample](docs/sample-report.json). Findings use stable upstream control IDs, native numeric values and SID arrays, expected/actual types, read evidence, remediation, applicability, and timestamps. All selected baseline controls are included in deterministic ID order. Reports include plugin version, baseline version and exact content SHA-256, execution timing, category and severity totals, and execution errors. Unsupported OS cannot select a baseline and therefore has an empty findings array with an explicit execution error.

| Status | Meaning |
| --- | --- |
| `Compliant` | A successful read matches the expected value and type |
| `NonCompliant` | A successful read differs |
| `NotApplicable` | A service is verified absent |
| `Error` | A read failed, was malformed, or returned no observation |
| `NotConfigured` | A required setting is absent |

The report is downloaded through Packer's communicator, assembled on the host, written to a sibling temporary file, synced, closed, and atomically renamed before enforcement. Existing reports are replaced. Temporary exports and scripts live under a unique `C:\Windows\Temp\packer-windows-checkup-*` guest directory and are removed after reporting. Cleanup failure is logged. No credentials or session authentication data are collected in findings; raw guest exception text is suppressed from reports.

## 🛠️ Architecture and development

`provisioner/` handles SDK config and orchestration; `guest/` embeds read-only Windows readers; `internal/facts/` classifies the OS; `internal/baseline/` owns the pinned contract; `internal/audit/` compares observations; `internal/report/` calculates summaries, writes JSON, and evaluates enforcement. New control types require an explicit baseline contract, reader, typed comparator, and tests. The guest has no apply or rollback path.

```powershell
gofmt -w main.go provisioner internal guest
go vet ./...
go test ./...
go build -ldflags '-X main.versionPrerelease=' -o bin/packer-plugin-windows-checkup.exe .
./bin/packer-plugin-windows-checkup.exe describe
pwsh -NoProfile -File scripts/check-powershell.ps1
pwsh -NoProfile -File scripts/test-powershell.ps1
```

If the normal Go build cache is unavailable, set `$env:GOCACHE = Join-Path (Get-Location) '.cache/go-build'`. CI checks formatting, Go vet static analysis, tests, PowerShell parsing and analysis, plugin describe, Packer configuration, and host-platform compilation. Tagged releases use GoReleaser with signed SHA-256 sums and draft GitHub releases, following the source project. See [live validation](test/integration/README.md); fixtures and unit tests are not evidence of a successful live WinRM audit.

## 🔧 Troubleshooting

For security-policy or audit errors, verify guest elevation and access to `secedit.exe` and `auditpol.exe`. Missing registry values are reported as missing, even where Windows might have a similar default: the source expects explicit policy. SID assignments use unordered, deduplicated sets and unresolved account names are errors. Services are checked for startup configuration only. Settings deferred by windows-harden to preserve WinRM may correctly remain noncompliant here; checkup never changes them.

For download errors, confirm WinRM remains available and the guest temporary directory is writable. For report errors, check host directory permissions and avoid using a directory as the filename. Review `executionErrors` as well as finding totals. An interrupted communicator transfer can prevent further guest reads; selected controls are then reported as errors, and the host report is still attempted.
