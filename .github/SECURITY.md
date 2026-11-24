# Security policy

## Supported versions

This project is pre-1.0 and has a single release line. The latest release is supported; older releases receive no backports.

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older releases | No |

## Reporting a vulnerability

Do not open a public issue, pull request or discussion.

Use [private vulnerability reporting](https://github.com/larskroghdk/packer-plugin-windows-checkup/security/advisories/new) through the repository's "Report a vulnerability" button on the Security tab.

Include the plugin version, Packer version and builder, guest OS and build, the provisioner block with secrets removed, and the relevant JSON report or `PACKER_LOG=1` output with secrets and sensitive host data removed. Describe steps to reproduce and the impact.

Do not include real credentials. Reproduce only on a disposable system you own or are authorized to test. Remove host names, domain names, IP addresses, account SIDs and sensitive compliance-report data.

## Scope

The plugin reads Windows security configuration over WinRM with elevated, 64-bit Windows PowerShell 5.1 and writes a JSON report on the Packer host.

In scope:

- A guest script or reader that changes guest state: writes settings or policy, changes services, schedules rollback or reboots.
- Configuration or guest data reaching PowerShell command text instead of JSON files.
- Credentials, WinRM passwords, tokens or session identity in reports, logs or release artifacts.
- Raw guest exception text leaking into reports or logs.
- A false `Compliant` result caused by a missing, unreadable or malformed observation, a wrong observed type or value, an unsupported OS reported as compliant, or wrong baseline or profile selection.
- Report tampering or integrity failures: writing to an unintended path, non-atomic writes, writing after enforcement instead of before, or enforcement passing when it should fail.
- Temporary guest files readable or replaceable by non-administrators, exports left behind, or cleanup that does not remove the unique temporary directory.
- Embedded baseline data not matching the pinned windows-harden snapshot or fingerprints.
- CI or release workflow weaknesses, including unpinned Actions or excess token permissions, that could compromise released binaries.

Out of scope:

- Microsoft baseline content itself. These are security-policy requirements, not vulnerabilities in this plugin.
- Windows, WinRM, `secedit`, `auditpol` or Packer/SDK vulnerabilities. Report Windows issues to the [Microsoft Security Response Center](https://msrc.microsoft.com/report) and Packer or SDK issues through [HashiCorp's security policy](https://www.hashicorp.com/security).
- Baselines or hardening behavior owned by windows-harden. Report those through the [windows-harden security policy](https://github.com/larskroghdk/packer-plugin-windows-harden/security/policy).
- Settings windows-harden deliberately defers, documented coverage limits, runtime state, service running state, Defender runtime health and domain GPO overrides.
- False `NonCompliant` results and other inaccurate findings that cannot hide a weaker configuration. Report these as normal bugs.

A passing report is not a certification of compliance with Microsoft baselines or any standard.

## Process

The single maintainer handles reports on a best-effort basis and coordinates disclosure with the reporter. Fixed issues are published through GitHub Security Advisories. Reporters are credited unless they prefer not to be.

## Report handling

Reports contain no credentials or session identity, but they are still sensitive: they expose the guest host name, OS build, domain profile, account SIDs in user-rights findings, and every setting that does not meet the baseline. Store reports in access-controlled locations and sanitize them before sharing.

## Verifying releases

Download `packer-plugin-windows-checkup_v<version>_SHA256SUMS` and its detached GPG signature from the GitHub release. Verify the signature, then check the released plugin files against the SHA-256 sums.
