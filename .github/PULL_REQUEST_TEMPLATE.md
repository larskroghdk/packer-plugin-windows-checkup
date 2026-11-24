## Summary

<!-- What changes and why? -->

## Related issues

<!-- `Closes #` / `Refs #`. -->

## Type of change

- [ ] Bug fix
- [ ] New or updated baseline
- [ ] New Windows support
- [ ] New control or reader
- [ ] Report format or field
- [ ] Configuration or enforcement option
- [ ] Documentation or GitHub automation
- [ ] Other

Breaking or behavioral change:

- [ ] Configuration semantics
- [ ] Report schema or fields
- [ ] Finding status semantics
- [ ] Supported OS or baseline selection
- [ ] None

## Testing

- [ ] `make check` passes
- [ ] `make generate-check` passes if a `mapstructure` field changed, or N/A
- [ ] `make validate` passes if configuration changed, or N/A
- [ ] New tests cover absent, empty, singleton and multiple-item observations plus error cases, or N/A
- [ ] Pester tests pass under Windows PowerShell 5.1, or N/A
- [ ] Live guest run: OS/build/profile and sanitized report, or "Not run" with reason

Mocked communicator tests do not verify a real WinRM build. Live evidence requires an opt-in run on a disposable guest.

## Audit accuracy

- [ ] The change remains read-only; it adds no guest writes or policy changes, or N/A
- [ ] `Compliant`, `NonCompliant`, `NotConfigured`, `NotApplicable` and `Error` are distinguished correctly, or N/A
- [ ] Unsupported OS remains an execution error, not a finding status, or N/A
- [ ] Missing, unreadable or malformed observations never count as compliant, or N/A
- [ ] Baseline selection and profile selection match the pinned windows-harden snapshot, or N/A
- [ ] Every selected control is reported in stable ID order, including inspection failures, or N/A
- [ ] Repeated runs give the same result for unchanged guest state, or N/A
- [ ] The WinRM session is not broken or hung, or N/A
- [ ] Temporary files are cleaned up; failures are logged, or N/A
- [ ] Baseline updates also update provenance, hashes, [docs/control-inventory.md](https://github.com/larskroghdk/packer-plugin-windows-checkup/blob/main/docs/control-inventory.md), and tests together, following the [baseline contract](https://github.com/larskroghdk/packer-plugin-windows-checkup/blob/main/docs/baseline-contract.md), or N/A

## Security

- [ ] No credentials, tokens, session identity or raw guest exception text appear in reports or logs, or N/A
- [ ] Guest input passes through JSON files rather than PowerShell command text, or N/A
- [ ] Temporary guest files are not readable or replaceable by non-administrators, or N/A
- [ ] Actions remain pinned to commit SHAs with minimum permissions, or N/A
- [ ] New dependencies are justified and `govulncheck` is clean, or N/A

## Compatibility

- [ ] Report schema, sample report and README remain consistent, or N/A
- [ ] A breaking report change updates `schemaVersion` in both [docs/report.schema.json](https://github.com/larskroghdk/packer-plugin-windows-checkup/blob/main/docs/report.schema.json) and `provisioner/provisioner.go`, or N/A
- [ ] Supported Windows versions and editions remain accurate, or N/A

## Invariants

Affected entries from [INVARIANTS.md](https://github.com/larskroghdk/packer-plugin-windows-checkup/blob/main/INVARIANTS.md), or `None`:

## Documentation

- [ ] README, docs or examples are updated for user-visible behavior, or N/A
- [ ] Go doc comments and PowerShell comment-based help follow I19, or N/A
- [ ] Release-note text is included here for a user-visible change, or N/A
