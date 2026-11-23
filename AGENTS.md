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
- After changing a `mapstructure` field, regenerate `provisioner/config.hcl2spec.go` with `make generate`, which installs the SDK generator at the version in go.mod. Don't edit it by hand.

## PowerShell

- Guests run elevated, 64-bit Windows PowerShell 5.1. Analysis under host `pwsh` doesn't show guest compatibility.
- Readers only read. Temporary exports, such as from `secedit` and `auditpol`, go in the working directory and must be cleaned up.
- Keep incidental output off the success pipeline and check native exit codes. Test absent, empty, singleton and multiple-item results against the Go consumer.

## Checks

CI is [.github/workflows/build.yml](.github/workflows/build.yml), and it runs the [Makefile](Makefile) targets. Before committing, run:

```sh
make check            # formatting, tidy, doccheck, staticcheck, PSScriptAnalyzer 1.22.0, packer fmt, actionlint,
                      # build and vet, govulncheck, report schema, go test, Pester 5.6.1 (guest and agent), build
make generate-check   # after changing a mapstructure field
make validate         # after configuration changes: installs the built plugin and runs packer validate examples/local
```

The guest Pester tests run under Windows PowerShell 5.1 (`make test-ps`), the agent workflow tests under PowerShell 7 (`make test-ai`). Normal tests never audit or change the development host's policy. Mocked tests don't show live WinRM behavior, so report them separately from live results.

## Agent workflow

Four agents work on this repository with fixed roles. [docs/ai-development.md](docs/ai-development.md) covers setup, the scripts and troubleshooting.

| Agent | Role | When |
| --- | --- | --- |
| Claude Code | Lead developer: decides the design, writes code and tests, coordinates the others, fixes review findings | Always |
| Gemini CLI | Read-only research and architecture challenges, through `scripts/ai/Invoke-GeminiResearch.ps1` | Major features, design decisions, dependency choices, hard problems |
| GitHub Copilot CLI | Documentation and `.github/` automation, through `scripts/ai/Invoke-CopilotMaintenance.ps1` | When docs or workflows must change |
| Codex CLI | Independent reviewer of every changeset, through the pre-commit hook | Every commit |

- Run the deterministic checks before asking for a review. The pre-commit hook runs the matching checks from `scripts/ai/settings.psd1` and then Codex on the exact staged snapshot. A commit is allowed only when Codex approves that changeset and reports no critical or high finding.
- An approval belongs to one changeset (base tree and result tree). Any change to the staged content needs a new review. The pre-push hook blocks commits without an approval; review them with `Invoke-CodexReview.ps1 -Commit <sha>`.
- Never bypass the hooks (`--no-verify`, `core.hooksPath` overrides) and never write to `.git/ai`. A failed or unavailable review blocks the commit. Fix the findings and commit again.
- Only Claude starts the other agents, and only through the scripts in `scripts/ai`. The agents those scripts start never start further agents and never commit or push; the scripts and hooks refuse to run under them (`AI_AGENT_ACTIVE`).
- When reviewing as Codex, report findings only. Don't edit files.

## Skills

- [go-development](.agents/skills/go-development/SKILL.md): Go changes to configuration, orchestration, comparison, classification and reporting.
- [powershell-development](.agents/skills/powershell-development/SKILL.md): the read-only guest readers and their Pester tests.
- [code-review](.agents/skills/code-review/SKILL.md): explicit reviews, audits and test-quality work.
- [update-baseline](.agents/skills/update-baseline/SKILL.md): aligning baseline data and the lifecycle table with windows-harden.
- [release-plugin](.agents/skills/release-plugin/SKILL.md): CI failures, packaging and authorized signed releases.

Activating a skill grants no authority to publish or to operate on a guest. [docs/agent-guidance.md](docs/agent-guidance.md) explains how each tool finds these files.
