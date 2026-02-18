---
doc_type: master_spec
product_name: AwakeBar
version: 1.2.0
status: active
owners:
  - dshakiba
last_reviewed: 2026-02-18
sources_of_truth:
  features_index: ./FEATURES.md
  product_map: ./PRODUCT_MAP.md
---

# Master Spec

## Product Vision

AwakeBar provides a minimal, menu bar-first experience for safely controlling macOS awake behavior in open-lid and privileged closed-lid scenarios.

## Release Scope (v1)

- [F-001] Open-lid keep-awake mode via IOKit assertions.
- [F-002] Menu bar interaction model with status feedback and setup/error cards.
- [F-003] Closed-lid control via `SMAppService` LaunchDaemon + XPC helper and guarded migration cleanup.
- [F-004] Safe persistence boundaries and launch-at-login control.
- [F-005] SVG-driven icon pipeline plus visual handoff documentation.
- [F-006] Signed/notarized distribution pipeline across local script and GitHub Actions.

## Constraints

- No credential storage in app runtime.
- Minimal memory and CPU footprint during idle operation.
- Native macOS interaction patterns only.
- Closed-lid control requires app installation in `/Applications`.
- No runtime fallback to legacy `sudo`/AppleScript privilege paths.

## Feature Coverage Snapshot

- Top-level active features: `F-001` through `F-006`.
- Child feature depth: one level (`F-xxx.yy`) for implementation-level traceability.
- Deprecated features: none.

## Architecture Decisions

- [ADR-0001](./DECISIONS/ADR-0001-privileged-daemon-cutover.md): LaunchDaemon + XPC hard cutover for closed-lid privilege path.
