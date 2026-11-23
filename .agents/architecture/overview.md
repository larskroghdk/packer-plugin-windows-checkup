# Project architecture and constraints

Paths in code spans are relative to the repository root. Existing project guidance is preserved below.

# 🔒 Invariants

- Guest scripts expose only Detect and Inspect. They never write security settings, apply policy, change service configuration, schedule rollback, or reboot.
- Every embedded source baseline and override has a corresponding tested validation. Control IDs and expected payloads retain upstream semantics. Fingerprints cover exact embedded JSON bytes.
- A missing, unreadable, malformed, or omitted observation never proves compliance. Explicit absence requirements and verified absent services have distinct handling.
- OS and domain membership select the baseline and profile. Unsupported systems report an execution error and no invented compliance.
- Every selected control appears in the report, in stable ID order, even after an inspection failure.
- The host report is persisted before compliance enforcement. Cancellation and report-writing failures return errors. Audit-only defaults do not turn findings into build failures.
- No credentials, authentication tokens, or session identity are collected in reports. Reader exceptions are represented without raw sensitive data.
- Packer configuration must pass both the SDK's typed HCL decoding path and actual `packer validate`.
- Normal tests and CI never audit or change the development host's security policy. Live Windows tests require explicit opt-in on a disposable guest.

## 📝 I19: Documentation conventions

Follow the source project's documentation convention: each Go function has a name-led doc comment with `Author: Lars Krogh`, a semantic `Version`, and a `Returns:` section for errors or multiple results. Exported types and packages have documentation. Generated files and functional directives are exempt. `cmd/doccheck` enforces the mechanical rules. PowerShell scripts and functions have comment-based help with descriptions, parameters, examples and author/version metadata. Keep operational explanations in Markdown.
