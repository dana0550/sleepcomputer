---
doc_type: master_spec
product_name: AwakeBar
version: 1.1.0
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

AwakeBar provides a minimal, menu bar-first experience for quickly controlling macOS awake behavior.

## Release Scope (v1)

- Lightweight menu bar app with no Dock icon.
- Open-lid keep-awake mode via IOKit assertions.
- Closed-lid mode via `SMAppService` LaunchDaemon + XPC helper.
- Guided setup state flow for helper registration and approval.
- One-time legacy privilege artifact cleanup with backup + safety guards.
- Startup restore of safe settings and launch-at-login toggle.
- SVG-driven iconography pipeline.

## Constraints

- No credential storage.
- Minimal memory and CPU footprint during idle operation.
- Native macOS interaction patterns.
- Closed-lid control requires app installation in `/Applications`.
- No runtime fallback to legacy `sudo`/AppleScript paths.

## Architecture Decisions

- [ADR-0001](./DECISIONS/ADR-0001-privileged-daemon-cutover.md): LaunchDaemon + XPC hard cutover for closed-lid privilege path.
