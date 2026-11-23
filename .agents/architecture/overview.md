# Architecture overview

This Packer provisioner audits Windows baseline compliance over the supplied WinRM communicator. [INVARIANTS.md](../../INVARIANTS.md) is the authoritative source of hard constraints and documentation rules.

- `main.go` registers the plugin and version.
- `provisioner/` owns Packer configuration, communicator calls, orchestration and report delivery.
- `internal/audit/` evaluates observations against controls; `internal/baseline/` owns embedded baseline data; `internal/facts/` interprets guest and OS facts.
- `internal/report/` owns report output. JSON contracts and report schemas must remain consistent with guest producers.
- `guest/` embeds the Windows PowerShell 5.1 Detect/Inspect readers. Normal development checks use fixtures and mocks; live auditing requires explicit opt-in.
- `cmd/doccheck/` checks source documentation. CI and PowerShell checks are defined in [.github/workflows/check.yml](../../.github/workflows/check.yml).

Use the shared standards for language and verification requirements. Read the relevant task skill explicitly; neither a skill nor a passing mocked test grants authority to operate on a live guest.
