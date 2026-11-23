# 🧪 Implementation validation — 2026-11-20

The baseline inventory was derived from windows-harden commit `2a3545f3a3b44c8fa84e3a22d28d999aece5daf6`. Six baseline files contain 2,187 entries and 18 non-domain-joined overrides. Tests exercise every entry in both profiles, including matching values, mismatches, missing configuration, missing reader data, and reader errors. File hashes verify the source snapshot.

✅ **Executed successfully:**

- Go formatting and the source project's documentation checker.
- `go test ./...`, including baseline selection, OS lifecycle classification, typed comparison, SID sets, report summaries, JSON serialization, atomic report replacement, SDK configuration, host reporting, enforcement and cancellation.
- `go vet ./...` static analysis.
- PowerShell parsing and PSScriptAnalyzer 1.22.0 at Error severity for all seven guest scripts.
- Six Pester 5.6.1 fixture tests, including explicit working-directory propagation and continuation after an export failure. The runner disables unused TestRegistry fixtures to avoid writing the development host registry.
- Windows amd64 and Linux amd64 native plugin compilation.
- Plugin `describe`, reporting API `x5.0`.
- Local Packer plugin installation into a repository-local plugin directory and `packer validate examples/local` with Packer 1.16.2. Validation uses a fixture host address and does not connect to Windows.
- Packer HCL formatting, sample JSON validation against the report schema, and GoReleaser configuration validation.

Actual Packer validation exposed the SDK's requirement for a generated `FlatMapstructure` adapter. The adapter is now generated, configuration defaults apply after SDK decoding, and regression tests pass decoded HCL values through `Prepare`.

The opt-in Windows integration test compiled and was **skipped** because `WINDOWS_CHECKUP_LIVE` was not set. No live Windows security audit, live WinRM build, GitHub Actions run, signed release, or publication was performed. Live validation on supported Windows OS/profile combinations remains necessary before treating the plugin as production-validated. The integration procedure and automated opt-in test are in `test/integration/`.

GitHub Actions additionally defines compilation for linux/darwin/windows on amd64/arm64 and signed public plugin releases; those remote jobs have not been executed in this session. Unit fixtures are not evidence of successful live validation.
