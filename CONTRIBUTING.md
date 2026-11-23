# 🤝 Contributing

Keep changes focused, idiomatic, and read-only. Exported Go declarations require documentation. PowerShell readers need comment-based help and must support Windows PowerShell 5.1. Preserve upstream author attribution and the MPL-2.0 license on derived source. Version releases with semantic `vMAJOR.MINOR.PATCH` tags.

Run `make check` before submitting. Add tests for reader errors, missing state, malformed state and mismatches whenever extending comparisons. Test SDK orchestration with protocol fixtures, and describe live Windows testing separately. Do not treat fixture results as live validation.

Baseline maintenance follows [contract 1.0](docs/baseline-contract.md). Reports must be written before compliance enforcement. Never add configuration writers, service changes, reboots, authentication collectors, or hardening actions to the guest package.

After changing configuration fields, run `make generate`, which installs the SDK generator at the version in go.mod. Commit `provisioner/config.hcl2spec.go` with the configuration change. CI verifies that generation produces no diff.
