---
name: update-baseline
description: Bring the embedded baselines or the OS lifecycle table in line with windows-harden (new or refreshed baseline, new Windows release, build, edition or LTSC release). Use when internal/baseline/data, data-manifest.json or internal/facts/lifecycle.go must change.
---

# Update a baseline

windows-checkup audits what windows-harden applies, so harden is the authority. Read [INVARIANTS.md](../../../INVARIANTS.md) and [docs/baseline-contract.md](../../../docs/baseline-contract.md). Commands and paths are relative to the repository root.

For a lifecycle-only change, use steps 1, 3, 4 and 6.

## Steps

1. **Establish the source.** Identify the windows-harden commit that contains the change and review what changed there: catalog data, model, readers, lifecycle classification, importer exclusions and application flow.
2. **Copy the data byte-for-byte** into `internal/baseline/data`. Never edit expected settings, least of all to make an audit pass. Regenerate the SHA-256 values and `sourceCommit` in [data-manifest.json](../../../internal/baseline/data-manifest.json), and regenerate [control-inventory.md](../../../docs/control-inventory.md). A new setting kind needs a read-only reader, a deterministic comparison in `internal/audit` and tests; an incompatible payload change needs a new contract version.
3. **Mirror lifecycle classification** in `internal/facts/lifecycle.go` (`serverReleases`, `clientReleases`, `enterpriseEditions`, `ltscEditions` and `ltscReleases`) so it matches harden's exactly. Client LTSC editions follow the fixed lifecycle of their LTSC release, with separate Enterprise and IoT Enterprise dates, and use the baseline of the general availability build Microsoft lists as equivalent. Selection is by product type and build, so an LTSC release on a known build picks that build's baseline. Classifying a release as supported does not establish that a baseline exists for it.
4. **Update the tests:** `TestClassify` in [facts_test.go](../../../internal/facts/facts_test.go) for releases, editions and last days of support; `TestCatalogSelect` in [catalog_test.go](../../../internal/baseline/catalog_test.go) when applicability changes. `TestSnapshotFingerprint` fails on any unrecorded data change.
5. **Review the result** against harden: control counts, removed or changed controls, and exclusions recorded in the inventory rather than turned into extra checks.
6. **Run the checks** in AGENTS.md and update the supported-system text in the README.

## Done when

- The checks pass.
- Data, manifest, inventory, lifecycle data, tests and the README agree with each other and with the named windows-harden commit.
- Live validation on the affected OS and profile is done, or reported as outstanding.
