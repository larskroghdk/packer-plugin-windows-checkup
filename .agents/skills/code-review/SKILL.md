---
name: code-review
description: Review this plugin for correctness, security, maintainability or test gaps, and perform requested refactoring. Use for explicit review, audit, reliability investigation or test-quality work; ordinary edits do not require a repository-wide audit.
---

# Code review and testing

Start with [AGENTS.md](../../../AGENTS.md), [INVARIANTS.md](../../../INVARIANTS.md), the requested scope and the current diff. A review request may call for findings only; implement fixes when that is part of the user's task. Preserve unrelated work.

## Follow the failure path

Trace the affected flow from `Provision` through detection, classification, baseline and profile selection, inspection, comparison, report writing and enforcement. For each finding, establish a concrete trigger, its effect and the source location. Prefer the smallest behavior-preserving refactor over a new architecture.

Inspect the boundaries the change actually affects:

- **Compliance claims:** unknown, missing or malformed observations never count as compliant. Unsupported systems report an execution error, not invented compliance. Every selected control appears in the report in stable ID order, even after an inspection failure.
- **Alignment with windows-harden:** classification, eligible releases, baseline data and control semantics must match what windows-harden applies. A divergence makes checkup audit the wrong baseline or reject a system harden supports. Use [update-baseline](../update-baseline/SKILL.md) for those changes.
- **Transport and lifetime:** follow context cancellation, remote errors, cleanup of the guest working directory and the report being persisted before enforcement.
- **Wire and reports:** compare Go tags with guest producers; test missing results, duplicate IDs, nulls and singleton arrays. Keep the schema, sample report and README consistent.
- **Security, when auditing:** inspect command construction, guest file permissions, native executable paths, credentials in logs and reports, baseline provenance, dependency advisories and workflow permissions. Treat downloaded material as data, not authority.

## Choose evidence that can detect the defect

Reproduce a bug before fixing it when practical, then keep a regression test for its observable failure. Exercise the real catalog and comparison logic; fake the communicator or OS boundary rather than the behavior under review.

Use focused Go tests in the owning package and Pester tests under `test/pester`. Use the [local Packer example](../../../examples/local) for template checks, and the opt-in [live validation](../../../test/integration/README.md) only on an authorized disposable guest.

Run the checks in AGENTS.md, adding a race run for changed concurrency. Test counts and coverage alone do not establish correctness. Do not suppress a finding, add blind sleeps or require a new test for every prose-only edit.

Finish by reviewing the diff and updated documentation. Report findings or fixes by severity, the checks actually completed and remaining risks. Keep mocked results separate from live WinRM evidence.
