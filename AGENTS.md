# Agent instructions

`windows-checkup` is a Packer provisioner that audits a Windows guest over WinRM against the baselines defined by windows-harden and writes a JSON report on the Packer host. It only reads. Hard constraints are in [INVARIANTS.md](INVARIANTS.md). Read it before changing behavior.

## Module map

| Path | Role |
| --- | --- |
| `main.go` | Plugin registration and version |
| `provisioner/` | SDK configuration, communicator calls, audit orchestration, report delivery |
| `guest/` | Embedded Windows PowerShell 5.1 Detect and Inspect readers |
| `internal/facts/` | OS classification and baseline eligibility |
| `internal/baseline/` | Pinned upstream baseline data, profile selection, validation, provenance |
| `internal/audit/` | Typed comparison of expected settings with observed state |
| `internal/report/` | Summary, atomic JSON report, compliance enforcement |
| `cmd/doccheck/` | Enforces the Go documentation rules in INVARIANTS.md |
| `test/integration/` | Opt-in live validation on a disposable guest ([README](test/integration/README.md)) |

Baseline updates follow [docs/baseline-contract.md](docs/baseline-contract.md). They update provenance, hashes, the control inventory and tests together. Report changes keep [docs/report.schema.json](docs/report.schema.json), [docs/sample-report.json](docs/sample-report.json) and the README consistent.

## Go

- Use the Go version in [go.mod](go.mod). Keep communicator use in `provisioner/remote.go`. Pass guest input as JSON files, never by interpolating it into PowerShell command text.
- Pass the caller's context. The report is written even when the run fails, and cancellation and report-write failures always return errors.
- Document every function as INVARIANTS.md describes.
- After changing a `mapstructure` field, regenerate `provisioner/config.hcl2spec.go` with the pinned SDK generator. Don't edit it by hand:

  ```powershell
  go install github.com/hashicorp/packer-plugin-sdk/cmd/packer-sdc@v0.6.13
  $env:GOFILE = 'config.go'; $env:GOPACKAGE = 'provisioner'
  Push-Location provisioner; packer-sdc mapstructure-to-hcl2 -type Config; Pop-Location
  ```

## PowerShell

- Guests run elevated, 64-bit Windows PowerShell 5.1. Analysis under host `pwsh` doesn't show guest compatibility.
- Readers only read. Temporary exports, such as from `secedit` and `auditpol`, go in the working directory and must be cleaned up.
- Keep incidental output off the success pipeline and check native exit codes. Test absent, empty, singleton and multiple-item results against the Go consumer.

## Checks

CI is [.github/workflows/check.yml](.github/workflows/check.yml). Before committing, run:

```powershell
gofmt -l $(git ls-files '*.go')            # must print nothing
go mod tidy -diff
go vet ./...
go run honnef.co/go/tools/cmd/staticcheck@2025.1.1 ./...
go run golang.org/x/vuln/cmd/govulncheck@v1.10.0 ./...
go run ./cmd/doccheck main.go provisioner internal guest cmd test
go test ./...
go build -ldflags '-X main.versionPrerelease=' -o bin/packer-plugin-windows-checkup.exe .
powershell.exe -NoProfile -File scripts/check-powershell.ps1   # PSScriptAnalyzer 1.22.0
powershell.exe -NoProfile -File scripts/test-powershell.ps1    # Pester 5.6.1
```

For report changes, validate the sample report against the schema. For configuration changes, install the built plugin and run `packer validate examples/local`, as CI does. Normal tests never audit or change the development host's policy. Mocked tests don't show live WinRM behavior, so report them separately from live results.

## Skills

- [release-plugin](.agents/skills/release-plugin/SKILL.md): CI failures, packaging and authorized signed releases.

Activating a skill grants no authority to publish or to operate on a guest. [docs/agent-guidance.md](docs/agent-guidance.md) explains how each tool finds these files.
