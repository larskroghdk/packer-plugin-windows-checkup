# GitHub Copilot instructions

## Project context

This repository implements `windows-checkup`, a native HashiCorp Packer provisioner written in Go with embedded Windows PowerShell readers. It independently audits the policies defined by windows-harden over Packer's WinRM communicator and writes a JSON report on the Packer host.

Read [INVARIANTS.md](../INVARIANTS.md) and [CONTRIBUTING.md](../CONTRIBUTING.md) before changing behavior. Use [README.md](../README.md) for configuration and report semantics, and [the baseline contract](../docs/baseline-contract.md) for imported policy changes.

## Architecture

- `provisioner/`: SDK configuration, communicator operations, and audit orchestration.
- `guest/`: embedded read-only Windows detection and inspection scripts.
- `internal/facts/`: OS classification and baseline eligibility.
- `internal/baseline/`: pinned upstream data, profile selection, validation, and provenance.
- `internal/audit/`: typed comparisons of expected settings and observed state.
- `internal/report/`: summaries, JSON persistence, and compliance enforcement.
- `cmd/doccheck/`: enforcement of Go documentation conventions.
- `test/integration/`: explicitly opted-in live Windows validation.

## Behavioral requirements

- Keep guest operations limited to Detect and Inspect. Never add policy writers, hardening, service changes, firewall changes, rollback tasks, shutdown, or reboot behavior. Temporary inspection exports are permitted and must be cleaned up.
- Audit actual guest state independently of windows-harden output, logs, or binaries. Preserve automatic OS and domain-profile selection; unsupported systems produce an execution error without invented compliance.
- Preserve upstream control IDs, expected values, types, and profile-override semantics. Never change expectations to make an audit pass. Baseline updates must follow the baseline contract and update provenance, hashes, inventory, and relevant tests together.
- Missing, unreadable, malformed, or omitted observations never establish compliance. Treat explicit absence requirements separately; an absent service is `NotApplicable` only after verifying that its service key is absent.
- Include every selected control in deterministic ID order, including after inspection failures. Keep configured-policy compliance distinct from effective runtime health.
- Persist the host report atomically before enforcing compliance. Preserve audit-only defaults, independent error enforcement, percentage calculation, and severity filtering. Cancellation and report-write failures always return errors.
- Never collect credentials, authentication tokens, or session identity in reports. Suppress raw guest exception text that could expose sensitive data.
- Version incompatible baseline payload or report changes through the relevant contract or schema. Keep the report schema, sample report, and documentation consistent with behavior.

## Implementation conventions

Keep changes focused and idiomatic. Use the Go version declared in `go.mod` and preserve compatibility with elevated 64-bit Windows PowerShell 5.1 on guests.

Every Go function needs a name-led doc comment with `Author: Lars Krogh`, a semantic `Version`, and a `Returns:` section for errors or multiple results. Document exported types and packages. Generated files and functional directives are exempt. PowerShell scripts and functions need comment-based help with descriptions, parameters, examples, and author/version metadata. Preserve upstream attribution and MPL-2.0 notices on derived source.

When changing configuration fields, regenerate `provisioner/config.hcl2spec.go` with the SDK version pinned in `go.mod`; do not edit the generated adapter by hand. The current generator workflow is:

```powershell
go install github.com/hashicorp/packer-plugin-sdk/cmd/packer-sdc@v0.6.13
$env:GOFILE = 'config.go'
$env:GOPACKAGE = 'provisioner'
Push-Location provisioner
packer-sdc mapstructure-to-hcl2 -type Config
Pop-Location
```

Commit the generated adapter with the configuration change. Verify both typed SDK HCL decoding and `packer validate` when changing configuration.

## Validation

Add tests for reader errors, missing state, malformed state, and mismatches when extending comparisons. Exercise SDK orchestration through protocol fixtures. Normal tests must never audit or change the development host's security policy; live validation requires explicit opt-in on a disposable Windows guest. Report fixture results and live WinRM evidence separately.

For code changes, format changed Go files and run the applicable checks from [CI](workflows/check.yml):

```powershell
go vet ./...
go run ./cmd/doccheck main.go provisioner internal guest cmd test
go test ./...
go build -ldflags '-X main.versionPrerelease=' -o bin/packer-plugin-windows-checkup.exe .
./bin/packer-plugin-windows-checkup.exe describe
pwsh -NoProfile -File scripts/check-powershell.ps1
pwsh -NoProfile -File scripts/test-powershell.ps1
```

PowerShell checks require the analyzer and Pester versions pinned in CI. For report changes, validate `docs/sample-report.json` against `docs/report.schema.json`. For configuration changes, install the local plugin and validate `examples/local` as CI does. Follow [the integration guide](../test/integration/README.md) for live validation after baseline or reader changes. State which checks ran and identify any unavailable prerequisites or untested live behavior.
