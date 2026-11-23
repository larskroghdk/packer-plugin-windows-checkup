---
name: go-development
description: Implement or debug Go changes in this Packer plugin, including configuration, audit orchestration, comparison, lifecycle classification and reporting. Use for Go behavior or package-boundary changes; baseline and lifecycle refreshes have their own skill.
---

# Go development

Read [AGENTS.md](../../../AGENTS.md) and [INVARIANTS.md](../../../INVARIANTS.md) before editing. Commands run from the repository root. Documentation requirements come from I19, including unexported and test functions.

## Locate the responsibility

- Keep guest facts and lifecycle classification in `internal/facts`, baseline loading, selection, validation and provenance in `internal/baseline`, the comparison of expected and observed state in `internal/audit`, and the summary, JSON report and enforcement in `internal/report`.
- Keep Packer configuration and orchestration in `provisioner`. All communicator use stays in [remote.go](../../../provisioner/remote.go); add an interface only when an actual consumer needs a smaller contract.
- Lifecycle data, baseline data and its provenance follow windows-harden. Use [update-baseline](../update-baseline/SKILL.md) for those, not ad-hoc edits.

## Implement the change

1. Trace the caller, state transition and failure path from `Provision` before choosing a patch. Preserve public configuration and the report schema unless the task requires a change; a report change keeps [report.schema.json](../../../docs/report.schema.json), [sample-report.json](../../../docs/sample-report.json) and the README consistent.
2. Keep errors actionable at the failing operation. Wrap with `%w` when callers need the underlying error; handle an error or return it rather than logging the same failure at every layer.
3. Pass the caller's context. The report is written even when the run fails, and cancellation and report-write failures always return errors. The SDK's `Upload` and `Download` have no context parameter, so a command timeout alone does not prove a transfer can be canceled.
4. Keep ownership explicit for files, streams, timers and goroutines. Avoid background work that outlives a provisioning run.
5. Validate guest JSON where it enters the model. A missing, unreadable or malformed observation stays unknown and never becomes compliant; an explicit absence requirement and a verified absent service are handled separately.

Pass guest input as JSON files through `remote.action`. Never interpolate setting data or credentials into PowerShell command text.

## Verify the behavior

Use table-driven tests for related input cases and the real comparison and catalog logic. Fake the communicator, not the behavior under review, and keep fakes in `_test.go` files. Same-package tests of unexported helpers are valid; do not export helpers just to test them.

Run focused `go test` cases while editing, then the checks in AGENTS.md. A `mapstructure` change requires `make generate`, a review of `provisioner/config.hcl2spec.go`, `make generate-check` once it is staged, and `make validate`. For concurrency changes, also run `go test -race ./...` where CGO and a C compiler are available, and report an unavailable race run explicitly.

Review the final diff for changed error semantics, dropped cleanup, new dependencies and accidental edits to embedded baseline data. Report which behavior was tested and what still needs a live guest.
