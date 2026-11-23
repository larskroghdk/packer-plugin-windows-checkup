---
applyTo: ".github/workflows/**"
---

# GitHub Actions rules

- Pin every action to a full commit SHA with the version as a comment, for example `actions/checkout@<sha> # v7.0.1`. Keep Dependabot's `github-actions` updates working.
- Set `permissions: contents: read` at the workflow level. Grant write permissions only to the job that needs them, such as the release job.
- Never put `${{ }}` expressions with untrusted input (branch names, PR titles, issue text) directly in `run`. Pass them through `env`.
- Keep secrets out of logs and out of steps that run code from pull requests. The release workflow is the only one that uses the signing secrets.
- Keep `build.yml` running the Makefile targets listed in AGENTS.md and the `agent-workflow` job, so CI runs the same checks as a local commit. Branch rules require the `check (ubuntu-latest)`, `check (windows-2025)`, `agent-workflow` checks.
- Validate with `actionlint` after every change.
